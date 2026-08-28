//
//  ContentView.swift
//  PortPeek
//

import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: PortMonitor
    @State private var searchText = ""
    @State private var protocolFilter = "TCP"
    @State private var expandedPort: String?
    @State private var selectedPortID: String?
    @FocusState private var isSearchFocused: Bool

    private var filteredPorts: [ListeningPort] {
        monitor.listeningPorts.filter { port in
            let matchesProtocol = port.protocolName == protocolFilter
            let matchesSearch = searchText.isEmpty || [port.command, port.port, port.address, port.protocolName, String(port.pid)].contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesProtocol && matchesSearch
        }
    }

    private var groupedPorts: [PortGroup] {
        let totalPortCountsByPID = Dictionary(
            grouping: monitor.listeningPorts.filter { $0.protocolName == protocolFilter },
            by: { $0.pid }
        ).mapValues(\.count)
        let groups = Dictionary(grouping: filteredPorts) { port in
            String(port.pid)
        }
        return groups.values
            .map { ports in
                PortGroup(
                    id: String(ports[0].pid),
                    ports: ports.sorted { (Int($0.port) ?? 0) < (Int($1.port) ?? 0) },
                    totalCount: totalPortCountsByPID[ports[0].pid] ?? ports.count
                )
            }
            .sorted { lhs, rhs in
                let lhsPort = Int(lhs.ports.first?.port ?? "") ?? 0
                let rhsPort = Int(rhs.ports.first?.port ?? "") ?? 0
                return lhsPort == rhsPort
                    ? (lhs.ports.first?.displayName ?? "") < (rhs.ports.first?.displayName ?? "")
                    : lhsPort < rhsPort
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            protocolBar
            Divider().overlay(Color.primary.opacity(0.12))
            searchField
            portList
            footer
        }
        .frame(width: 360, height: 510)
        .background(.clear)
        .containerBackground(.regularMaterial, for: .window)
        .onAppear {
            Task { @MainActor in
                isSearchFocused = true
            }
        }
    }

    private var protocolBar: some View {
        HStack(spacing: 12) {
            Picker("协议", selection: $protocolFilter) {
            Text("TCP \(monitor.listeningPorts.filter { $0.protocolName == "TCP" }.count)").tag("TCP")
            Text("UDP \(monitor.listeningPorts.filter { $0.protocolName == "UDP" }.count)").tag("UDP")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 175)
            Spacer(minLength: 8)
            Text(Date.now, style: .time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
            Button(action: monitor.refresh) {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: monitor.isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .help("刷新端口")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("按端口号或进程名筛选", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
    }

    private var portList: some View {
        List(selection: $selectedPortID) {
            if filteredPorts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: monitor.lastError == nil && searchText.isEmpty ? "checkmark.shield" : "exclamationmark.triangle")
                        .font(.system(size: 22, weight: .medium)).foregroundStyle(.secondary)
                    Text(monitor.lastError ?? (searchText.isEmpty ? "没有发现监听端口" : "没有匹配结果")).font(.body.weight(.medium))
                    Text(monitor.lastError == nil ? (searchText.isEmpty ? "当前没有正在监听的 TCP 或 UDP 端口。" : "请尝试其他端口号或进程名。") : "请点击刷新重试。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 64)
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedPorts) { group in
                    Section {
                        portRows(for: group.ports)
                    } header: {
                        PortGroupHeader(
                            port: group.ports[0],
                            count: group.ports.count,
                            totalCount: group.totalCount
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.vertical, 0, for: .scrollContent)
        .environment(\.defaultMinListRowHeight, 0)
    }

    @ViewBuilder
    private func portRows(for ports: [ListeningPort]) -> some View {
        ForEach(ports) { port in
            PortRow(
                port: port,
                isExpanded: expandedPort == port.id,
                onToggle: {
                    selectedPortID = port.id
                    expandedPort = expandedPort == port.id ? nil : port.id
                },
                onStop: { monitor.stop(port) },
                onForceStop: { monitor.forceStop(port) }
            )
            .tag(port.id)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
        }
    }

    private var footer: some View {
        HStack {
            Label("仅本机", systemImage: "lock.shield")
            Spacer()
            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .font(.caption2).padding(.horizontal, 18).padding(.vertical, 10)
    }
}

private struct PortGroup: Identifiable {
    let id: String
    let ports: [ListeningPort]
    let totalCount: Int
}

private struct PortGroupHeader: View {
    let port: ListeningPort
    let count: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 6) {
            if let appIcon = port.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(port.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("PID \(port.pid)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(count == totalCount
                ? String(count) + " 个端口"
                : "匹配 " + String(count) + " / 共 " + String(totalCount) + " 个端口")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
        }
        .textCase(nil)
        .padding(.vertical, 3)
        .listRowSeparator(.hidden)
    }
}
