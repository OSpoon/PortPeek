//
//  ContentView.swift
//  RunStat
//

import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: PortMonitor
    @State private var searchText = ""
    @State private var protocolFilter = "TCP"
    @State private var expandedPort: String?

    private var filteredPorts: [ListeningPort] {
        monitor.listeningPorts.filter { port in
            let matchesProtocol = port.protocolName == protocolFilter
            let matchesSearch = searchText.isEmpty || [port.command, port.port, port.address, port.protocolName, String(port.pid)].contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesProtocol && matchesSearch
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
            TextField("按端口号或进程名筛选", text: $searchText).textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var portList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
            if filteredPorts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: monitor.lastError == nil && searchText.isEmpty ? "checkmark.shield" : "exclamationmark.triangle")
                        .font(.system(size: 22, weight: .medium)).foregroundStyle(.secondary)
                    Text(monitor.lastError ?? (searchText.isEmpty ? "没有发现监听端口" : "没有匹配结果")).font(.body.weight(.medium))
                    Text(monitor.lastError == nil ? (searchText.isEmpty ? "当前没有正在监听的 TCP 或 UDP 端口。" : "请尝试其他端口号或进程名。") : "请点击刷新重试。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 64).listRowBackground(Color.clear)
            } else {
                ForEach(filteredPorts) { port in
                    VStack(spacing: 0) {
                        PortRow(port: port, isExpanded: expandedPort == port.id, onToggle: { expandedPort = expandedPort == port.id ? nil : port.id }, onStop: { monitor.stop(port) }, onForceStop: { monitor.forceStop(port) })
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .padding(.leading, 54)
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            }
            .padding(.horizontal, 0)
        }
        .scrollIndicators(.automatic)
    }

    private var footer: some View {
        HStack {
            Label("仅本机", systemImage: "lock.shield")
            Spacer()
            Button("退出 RunStat") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .font(.caption2).padding(.horizontal, 18).padding(.vertical, 10)
    }
}
