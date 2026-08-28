//
//  PortMonitor.swift
//  RunStat
//

import Combine
import Foundation

@MainActor
final class PortMonitor: ObservableObject {
    @Published private(set) var listeningPorts: [ListeningPort] = []
    @Published private(set) var isRefreshing = false
    @Published var lastError: String?

    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?

    init() {
        refresh()
        startRefreshTimer()
    }

    deinit {
        refreshTask?.cancel()
        refreshTimer?.invalidate()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        refreshTask?.cancel()
        isRefreshing = true
        refreshTask = Task { [weak self] in
            let result = await Self.readListeningPorts()
            guard !Task.isCancelled else { return }
            self?.listeningPorts = result.ports
            self?.lastError = result.error
            self?.isRefreshing = false
        }
    }

    func stop(_ port: ListeningPort) {
        guard port.isOwnedByCurrentUser else {
            lastError = "仅支持结束当前用户拥有的进程。"
            return
        }
        if kill(port.pid, SIGTERM) != 0 {
            lastError = "无法结束 \(port.command)（PID \(port.pid)）。"
        } else {
            refresh()
        }
    }

    func forceStop(_ port: ListeningPort) {
        guard port.isOwnedByCurrentUser else {
            lastError = "仅支持强制结束当前用户拥有的进程。"
            return
        }
        if kill(port.pid, SIGKILL) != 0 {
            lastError = "无法强制结束 \(port.command)（PID \(port.pid)）。"
        } else {
            refresh()
        }
    }

    private struct ScanResult: Sendable {
        let ports: [ListeningPort]
        let error: String?
    }

    private static func readListeningPorts() async -> ScanResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-iUDP"]
            process.standardOutput = output
            process.standardError = Pipe()
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self)
                var detailsCache = ProcessDetailsCache()
                let lsofPorts = process.terminationStatus == 0 ? parse(text, detailsCache: &detailsCache) : []
                let ports = lsofPorts
                let known = Set(ports.map { "\($0.protocolName)-\($0.port)" })
                let fallback = ports.isEmpty
                    ? parseNetstat(detailsCache: &detailsCache).filter { !known.contains("\($0.protocolName)-\($0.port)") }
                    : []
                let projectNames = await dockerProjectNameCache.value()
                let allPorts = (ports + fallback).map { port in
                    let key = "\(port.protocolName)-\(port.port)"
                    return port.withProjectName(projectNames[key] ?? projectNames[port.port])
                }.filter { isUserManagedPort($0) }
                if allPorts.isEmpty && process.terminationStatus != 0 {
                    return ScanResult(ports: [], error: "无法读取监听端口，请检查系统权限。")
                }
                return ScanResult(ports: allPorts, error: nil)
            } catch {
                return ScanResult(ports: [], error: "端口扫描失败：\(error.localizedDescription)")
            }
        }.value
    }

    /// PortPeek intentionally exposes only ports owned by the current user.
    /// System/root services are not part of the product surface and cannot be
    /// acted on from the UI.
    nonisolated private static func isUserManagedPort(_ port: ListeningPort) -> Bool {
        guard port.pid > 1, port.user == NSUserName() else { return false }
        guard let executablePath = port.storedExecutablePath else { return true }
        let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/"]
        return !systemPrefixes.contains { executablePath.hasPrefix($0) }
    }

    nonisolated private static func parse(_ text: String, detailsCache: inout ProcessDetailsCache) -> [ListeningPort] {
        struct Aggregate {
            let command: String
            let pid: Int32
            let user: String
            let protocolName: String
            let port: String
            var addresses: Set<String> = []
            var hasIPv4 = false
            var hasIPv6 = false
        }
        var aggregates: [String: Aggregate] = [:]
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard columns.count >= 9, let pid = Int32(columns[1]) else { continue }
            let proto = columns[7].uppercased()
            guard proto == "TCP" || proto == "UDP" else { continue }
            let rawName = columns.dropFirst(8).joined(separator: " ")
            let endpointToken = rawName.split(separator: " ").first.map(String.init) ?? rawName
            // UDP entries may contain a remote endpoint (`local->remote`).
            // Only the local endpoint represents the bound port.
            let endpoint = endpointToken.components(separatedBy: "->").first ?? endpointToken
            guard let separator = endpoint.lastIndex(of: ":") else { continue }
            var address = String(endpoint[..<separator])
            let port = String(endpoint[endpoint.index(after: separator)...])
            guard port.allSatisfy(\.isNumber), !port.isEmpty else { continue }
            // For wildcard IPv6 sockets lsof prints `*:port`, so the address
            // alone is not enough to determine the IP family. Use TYPE first.
            let socketType = columns[5].uppercased()
            let ipv6 = socketType == "IPV6" || address.hasPrefix("[") || address.contains(":")
            address = address.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let key = "\(pid)-\(proto)-\(port)"
            if aggregates[key] == nil {
                aggregates[key] = Aggregate(command: columns[0], pid: pid, user: columns[2], protocolName: proto, port: port)
            }
            if var aggregate = aggregates[key] {
                aggregate.addresses.insert(address.isEmpty ? "*" : address)
                aggregate.hasIPv6 = aggregate.hasIPv6 || ipv6
                aggregate.hasIPv4 = aggregate.hasIPv4 || !ipv6
                aggregates[key] = aggregate
            }
        }
        var result: [ListeningPort] = []
        for aggregate in aggregates.values {
            let details = detailsCache.details(for: aggregate.pid)
            let addresses = aggregate.addresses.sorted()
            let address = addresses.joined(separator: " · ")
            result.append(ListeningPort(command: aggregate.command, pid: aggregate.pid, user: aggregate.user, protocolName: aggregate.protocolName, address: address, port: aggregate.port, isIPv6: aggregate.hasIPv6 && !aggregate.hasIPv4, isDualStack: aggregate.hasIPv4 && aggregate.hasIPv6, commandLine: details.commandLine, parentPID: details.parentPID, startedAt: details.startedAt, storedExecutablePath: details.executablePath, workingDirectory: details.workingDirectory, serviceName: serviceName(for: aggregate.port, command: "\(aggregate.command) \(details.commandLine)"), projectName: nil))
        }
        return result.sorted { (Int($0.port) ?? 0, $0.command) < (Int($1.port) ?? 0, $1.command) }
    }

    nonisolated private static func parseNetstat(detailsCache: inout ProcessDetailsCache) -> [ListeningPort] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-anv"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            var result: [ListeningPort] = []
            var seen = Set<String>()
            for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
                let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard let family = columns.first, ["tcp4", "tcp6", "tcp46", "udp4", "udp6"].contains(family) else { continue }
                if family.hasPrefix("tcp") && !columns.contains("LISTEN") { continue }
                // netstat column layouts differ between macOS releases. Find
                // the first endpoint token with a numeric local port instead
                // of assuming a fixed column index.
                guard let endpoint = columns.dropFirst().first(where: { token in
                    guard let separator = token.lastIndex(of: ".") else { return false }
                    let port = token[token.index(after: separator)...]
                    return !port.isEmpty && port.allSatisfy(\.isNumber)
                }), let separator = endpoint.lastIndex(of: ".") else { continue }
                let port = String(endpoint[endpoint.index(after: separator)...])
                guard port.allSatisfy(\.isNumber), !port.isEmpty else { continue }
                let proto = family.hasPrefix("tcp") ? "TCP" : "UDP"
                let key = "\(proto)-\(port)"
                guard seen.insert(key).inserted else { continue }
                let address = String(endpoint[..<separator])
                let processToken = columns.dropFirst().last(where: { token in
                    guard let separator = token.lastIndex(of: ":"), let pid = Int32(token[token.index(after: separator)...]) else { return false }
                    return pid > 0
                })
                let processName: String
                let processPID: Int32
                if let processToken, let separator = processToken.lastIndex(of: ":"), let pid = Int32(processToken[processToken.index(after: separator)...]) {
                    processName = String(processToken[..<separator])
                    processPID = pid
                } else {
                    processName = "system service"
                    processPID = 0
                }
                let details = processPID > 0 ? detailsCache.details(for: processPID) : ProcessDetails(user: "root", commandLine: "—", parentPID: 1, startedAt: nil, executablePath: nil, workingDirectory: nil)
                let isIPv6 = family == "tcp6" || family == "udp6"
                let isDualStack = family == "tcp46"
                result.append(ListeningPort(command: processName, pid: processPID, user: details.user, protocolName: proto, address: address, port: port, isIPv6: isIPv6, isDualStack: isDualStack, commandLine: details.commandLine, parentPID: details.parentPID, startedAt: details.startedAt, storedExecutablePath: details.executablePath, workingDirectory: details.workingDirectory, serviceName: serviceName(for: port, command: "\(processName) \(details.commandLine)"), projectName: nil))
            }
            return result
        } catch {
            return []
        }
    }

    private actor DockerProjectNameCache {
        private var cachedNames: [String: String] = [:]
        private var cachedAt: Date?

        func value() -> [String: String] {
            if let cachedAt, Date().timeIntervalSince(cachedAt) < 20 {
                return cachedNames
            }
            let names = PortMonitor.queryDockerProjectNames()
            cachedNames = names
            cachedAt = Date()
            return names
        }
    }

    private static let dockerProjectNameCache = DockerProjectNameCache()

    /// Docker and OrbStack expose container port mappings through the Docker CLI.
    /// This is deliberately optional: a missing or stopped daemon must not block scanning.
    nonisolated private static func queryDockerProjectNames() -> [String: String] {
        let process = Process()
        let output = Pipe()
        let dockerCandidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/usr/bin/docker"
        ]
        guard let dockerPath = dockerCandidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return [:]
        }
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = ["ps", "--format", "{{.Names}}\t{{.Ports}}"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [:] }
            var result: [String: Set<String>] = [:]
            for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
                let columns = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard columns.count == 2 else { continue }
                let name = columns[0]
                for mapping in columns[1].split(separator: ",") {
                    let left = mapping.components(separatedBy: "->").first ?? ""
                    guard let separator = left.lastIndex(of: ":") else { continue }
                    let port = String(left[left.index(after: separator)...])
                    guard port.allSatisfy(\.isNumber) else { continue }
                    let protocolName = mapping.lowercased().contains("/udp") ? "UDP" : "TCP"
                    result["\(protocolName)-\(port)", default: []].insert(name)
                }
            }
            return result.reduce(into: [String: String]()) { result, item in
                let names = item.value.sorted().joined(separator: " · ")
                result[item.key] = names
                if let port = item.key.split(separator: "-").last {
                    result[String(port)] = names
                }
            }
        } catch {
            return [:]
        }
    }

    private struct ProcessDetails {
        let user: String
        let commandLine: String
        let parentPID: Int32?
        let startedAt: String?
        let executablePath: String?
        let workingDirectory: String?
    }

    private struct ProcessDetailsCache {
        private var values: [Int32: ProcessDetails] = [:]

        mutating func details(for pid: Int32) -> ProcessDetails {
            if let cached = values[pid] { return cached }
            let details = processDetails(for: pid)
            values[pid] = details
            return details
        }
    }

    nonisolated private static func processDetails(for pid: Int32) -> ProcessDetails {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "user=", "-o", "ppid=", "-o", "lstart=", "-o", "command="]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let columns = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace).map(String.init)
            guard columns.count >= 8 else { return ProcessDetails(user: "root", commandLine: "—", parentPID: nil, startedAt: nil, executablePath: nil, workingDirectory: nil) }
            let commandLine = columns.dropFirst(7).joined(separator: " ")
            let executablePath = commandLine.split(separator: " ").first.map(String.init).flatMap { $0.hasPrefix("/") ? $0 : nil }
            let paths = filePaths(for: pid)
            return ProcessDetails(user: columns[0], commandLine: commandLine, parentPID: Int32(columns[1]), startedAt: columns[2...6].joined(separator: " "), executablePath: paths.executable ?? executablePath, workingDirectory: paths.cwd)
        } catch {
            return ProcessDetails(user: "root", commandLine: "—", parentPID: nil, startedAt: nil, executablePath: nil, workingDirectory: nil)
        }
    }

    nonisolated private static func filePaths(for pid: Int32) -> (cwd: String?, executable: String?) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-a", "-p", String(pid), "-d", "cwd,txt", "-Fn"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            var cwd: String?
            var executable: String?
            var currentField: String?
            for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
                if line == "fcwd" || line == "ftxt" {
                    currentField = String(line.dropFirst())
                    continue
                }
                guard line.hasPrefix("n"), let field = currentField else { continue }
                let value = String(line.dropFirst())
                if field == "cwd" { cwd = value }
                if field == "txt", executable == nil, !value.hasSuffix("/dyld") {
                    executable = value
                }
                currentField = nil
            }
            return (cwd, executable)
        } catch {
            return (nil, nil)
        }
    }

    nonisolated private static func serviceName(for port: String, command: String) -> String? {
        let known: [String: String] = ["22": "SSH", "80": "HTTP", "443": "HTTPS", "3000": "HTTP", "3306": "MySQL", "5432": "PostgreSQL", "6379": "Redis", "8080": "HTTP", "8443": "HTTPS"]
        if let service = known[port] { return service }
        let lower = command.lowercased()
        if lower.contains("nginx") || lower.contains("apache") { return "HTTP" }
        if lower.contains("mysql") { return "MySQL" }
        if lower.contains("postgres") { return "PostgreSQL" }
        if lower.contains("redis") { return "Redis" }
        if lower.contains("mongodb") || lower.contains("mongod") { return "MongoDB" }
        if lower.contains("memcached") { return "Memcached" }
        return nil
    }
}
