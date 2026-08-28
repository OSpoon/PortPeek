//
//  PortRow.swift
//  PortPeek
//

import AppKit
import SwiftUI

struct PortRow: View {
    let port: ListeningPort
    let isExpanded: Bool
    let onToggle: () -> Void
    let onStop: () -> Void
    let onForceStop: () -> Void

    @State private var showingForceStopConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if let appIcon = port.appIcon {
                        Image(nsImage: appIcon).resizable().scaledToFit().padding(2)
                    } else {
                        TerminalProcessIcon()
                    }
                }
                .frame(width: 28, height: 28)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(port.displayName).font(.body.weight(.medium)).lineLimit(1).truncationMode(.tail)
                        if let identityBadge = port.identityBadge {
                            let identityColor = port.projectName == nil ? badgeColor(for: identityBadge) : Color.cyan
                            Text(identityBadge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(identityColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(identityColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .lineLimit(1)
                        }
                        if port.isExposed { Image(systemName: "wifi").font(.caption2).foregroundStyle(.orange).help("对外开放") }
                        if port.isLaunchdManaged { Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.secondary).help("由 launchd 托管，结束后会自动重启") }
                    }
                    HStack(spacing: 6) {
                        Text(port.port).font(.system(.subheadline, design: .monospaced).weight(.semibold)).lineLimit(1).fixedSize()
                        Text(port.protocolName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                        Text(port.isDualStack ? "IPv4·IPv6" : (port.isIPv6 ? "IPv6" : "IPv4"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .fixedSize()
                        Text("PID \(String(port.pid))").font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                        Text("·").foregroundStyle(.tertiary).fixedSize()
                        Text(port.address.isEmpty ? "*" : port.address)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .layoutPriority(-1)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 42)
            if isExpanded { details }
        }
        // Keep the summary row anchored; expansion only appends details below it.
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            Button { onToggle() } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .padding(.trailing, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            applicationContextMenu
        }
        .confirmationDialog(
            "强制结束进程？",
            isPresented: $showingForceStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("强制结束 " + port.command + "（PID " + String(port.pid) + "）", role: .destructive) {
                onForceStop()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("SIGKILL 会立即终止进程，进程来不及保存数据或执行清理操作。")
        }
    }

    @ViewBuilder
    private var applicationContextMenu: some View {
        Button("在 Finder 中显示") { revealInFinder() }
            .disabled(port.executableURL == nil)
        Button("在 Finder 中显示项目") { revealProjectInFinder() }
            .disabled(port.workingDirectory == nil)
        Button("在终端打开项目") { openInTerminal() }
            .disabled(port.workingDirectory == nil)

        Menu("用编辑器打开") {
            Button("默认编辑器") { openWithDefaultEditor() }
            Button("TextEdit") { openWithTextEdit() }
        }
        .disabled(port.executableURL == nil)

        Divider()
        Button("复制 localhost:\(port.port)") { copy("localhost:\(port.port)") }
        Button("复制项目路径") { copy(port.workingDirectory ?? "") }
            .disabled(port.workingDirectory == nil)
        Button("拷贝 PID") { copy(String(port.pid)) }
        Button("拷贝端口号") { copy(port.port) }
        if port.isLaunchdManaged {
            Divider()
            Button("打开“登录项与扩展”设置") { openLoginItemsSettings() }
        }
        Divider()
        Menu("结束进程") {
            Button("正常结束") { onStop() }
            Button("强制结束 (SIGKILL)", role: .destructive) {
                showingForceStopConfirmation = true
            }
        }
    }

    private var launchdWarning: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("此进程由系统守护，结束后会自动重启。要彻底停用，请在“登录项与扩展”列表中关闭它所属 App。", systemImage: "info.circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 4)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            if port.isLaunchdManaged {
                launchdWarning
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow { Text("绑定地址").foregroundStyle(.secondary); Text(port.address.isEmpty ? "*" : port.address) }
            GridRow { Text("网络范围").foregroundStyle(.secondary); Text(port.isExposed ? "对外开放" : "仅本机").foregroundStyle(port.isExposed ? .orange : .secondary) }
            if let serviceName = port.serviceName {
                GridRow { Text("服务").foregroundStyle(.secondary); Text(serviceName) }
            }
            GridRow { Text("命令").foregroundStyle(.secondary); Text(port.commandLine).textSelection(.enabled) }
            GridRow { Text("路径").foregroundStyle(.secondary); Text(port.executablePath ?? "—").textSelection(.enabled) }
            GridRow { Text("目录").foregroundStyle(.secondary); Text(port.workingDirectory ?? "—").textSelection(.enabled) }
            GridRow { Text("启动时间").foregroundStyle(.secondary); Text(port.startedAt ?? "—") }
            GridRow {
                Text("用户").foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text(port.user)
                    Text("·").foregroundStyle(.tertiary)
                    Text("父进程") .foregroundStyle(.secondary)
                    Text(port.parentPID.map(String.init) ?? "—")
                }
            }
            }
        }
        .font(.caption.monospaced())
        .padding(.leading, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func badgeColor(for badge: String) -> Color {
        switch badge {
        case "MySQL", "Postgres", "PostgreSQL", "Redis", "MongoDB", "Memcached": return .orange
        case "Docker", "Podman", "OrbStack": return .cyan
        case "Vite", "Webpack", "Nuxt", "Astro", "Remix", "NestJS", "Storybook": return .blue
        case "Django", "FastAPI / Uvicorn", "Gunicorn", "Flask", "Rails", "Puma", "Sidekiq", "Spring Boot", "Tomcat", "Quarkus", "Laravel": return .green
        default: return .purple
        }
    }

    private func revealInFinder() {
        guard let url = port.executableURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openInTerminal() {
        guard let path = port.workingDirectory else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }

    private func revealProjectInFinder() {
        guard let path = port.workingDirectory else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func openWithDefaultEditor() {
        guard let url = port.executableURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func openWithTextEdit() {
        guard let url = port.executableURL else { return }
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct TerminalProcessIcon: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.10), Color(white: 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            Text("exec")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
                .padding(.leading, 4)
                .padding(.top, 5)
        }
        .frame(width: 24, height: 24)
        .frame(width: 28, height: 28)
        .accessibilityLabel("命令行进程")
    }
}
