//
//  PortModels.swift
//  PortPeek
//

import AppKit
import Foundation

struct ListeningPort: Identifiable, Hashable {
    let command: String
    let pid: Int32
    let user: String
    let protocolName: String
    let address: String
    let port: String
    let isIPv6: Bool
    let isDualStack: Bool
    let commandLine: String
    let parentPID: Int32?
    let startedAt: String?
    let storedExecutablePath: String?
    let workingDirectory: String?
    let serviceName: String?
    let projectName: String?

    var id: String { "\(pid)-\(protocolName)-\(address)-\(port)" }

    var isOwnedByCurrentUser: Bool { user == NSUserName() }
    var isRootOrSystemProcess: Bool { user == "root" || !isOwnedByCurrentUser }
    var isLaunchdManaged: Bool { parentPID == 1 }
    var runningApplication: NSRunningApplication? { NSRunningApplication(processIdentifier: pid) }
    var executableURL: URL? {
        if let url = runningApplication?.executableURL { return url }
        if let path = storedExecutablePath { return URL(fileURLWithPath: path) }
        return nil
    }
    var executablePath: String? { executableURL?.path ?? storedExecutablePath }

    /// Finds the owning application, including helpers nested inside an .app bundle.
    var applicationBundleURL: URL? {
        guard var url = executableURL else { return nil }
        var outermost: URL?
        while url.path != "/" {
            if url.pathExtension == "app" { outermost = url }
            url.deleteLastPathComponent()
        }
        return outermost
    }

    var appIcon: NSImage? {
        if let bundleURL = applicationBundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
        if isRootOrSystemProcess, let path = storedExecutablePath, command.lowercased() != "launchd" {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }

    var displayName: String {
        if isRootOrSystemProcess, let path = storedExecutablePath, !path.isEmpty {
            return path
        }
        if let bundle = applicationBundleURL.flatMap(Bundle.init(url:)),
           let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) {
            return name
        }
        return runningApplication?.localizedName ?? command
    }

    /// Extra identity shown beside the app name, matching Pier's project/tool badge.
    var identityBadge: String? {
        if let projectName { return projectName }
        let commandText = "\(commandLine) \(workingDirectory ?? "")".lowercased()
        let tools: [(String, String)] = [
            ("next-server", "Next.js"), ("next dev", "Next.js"), ("vite", "Vite"),
            ("webpack", "Webpack"), ("nuxt", "Nuxt"), ("astro", "Astro"),
            ("remix", "Remix"), ("nest", "NestJS"), ("storybook", "Storybook"),
            ("django", "Django"), ("uvicorn", "FastAPI / Uvicorn"), ("fastapi", "FastAPI / Uvicorn"),
            ("gunicorn", "Gunicorn"), ("flask", "Flask"), ("rails", "Rails"),
            ("puma", "Puma"), ("sidekiq", "Sidekiq"), ("spring boot", "Spring Boot"),
            ("tomcat", "Tomcat"), ("quarkus", "Quarkus"), ("artisan", "Laravel"),
            ("docker", "Docker"), ("podman", "Podman"), ("orbStack", "OrbStack"),
            ("tailscale", "Tailscale"), ("cloudflared", "Cloudflare Tunnel"), ("ngrok", "ngrok"),
            ("postgres", "Postgres"), ("mysqld", "MySQL"), ("redis-server", "Redis"),
            ("mongod", "MongoDB"), ("memcached", "Memcached")
        ]
        if let tool = tools.first(where: { commandText.contains($0.0.lowercased()) }) { return tool.1 }
        return nil
    }

    var isExposed: Bool {
        address.split(separator: "·").contains { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized.isEmpty || normalized == "*" || normalized == "0.0.0.0" || normalized == "::"
        }
    }

    nonisolated func withProjectName(_ name: String?) -> ListeningPort {
        ListeningPort(command: command, pid: pid, user: user, protocolName: protocolName, address: address, port: port, isIPv6: isIPv6, isDualStack: isDualStack, commandLine: commandLine, parentPID: parentPID, startedAt: startedAt, storedExecutablePath: storedExecutablePath, workingDirectory: workingDirectory, serviceName: serviceName, projectName: name)
    }
}
