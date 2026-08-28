//
//  PortRow.swift
//  RunStat
//

import AppKit
import SwiftUI

struct PortRow: View {
    let port: ListeningPort
    let isExpanded: Bool
    let onToggle: () -> Void
    let onStop: () -> Void
    let onForceStop: () -> Void
    @State private var isHovered = false
    @State private var isConfirmingStop = false

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
                            Text(identityBadge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(badgeColor(for: identityBadge))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(badgeColor(for: identityBadge).opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .lineLimit(1)
                        }
                        if port.isExposed { Image(systemName: "wifi").font(.caption2).foregroundStyle(.orange).help("对外开放") }
                        if port.isLaunchdManaged { Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.secondary).help("由 launchd 托管，结束后会自动重启") }
                        if port.isRootOrSystemProcess { Image(systemName: "gearshape.fill").font(.caption2).foregroundStyle(.secondary).help("系统进程") }
                    }
                    HStack(spacing: 6) {
                        Text(port.port).font(.system(.subheadline, design: .monospaced).weight(.semibold)).lineLimit(1).fixedSize()
                        Text(port.protocolName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                        Text(port.isDualStack ? "IPv4·IPv6" : (port.isIPv6 ? "IPv6" : "IPv4")).font(.caption2).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                        Text("PID \(String(port.pid))").font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                        Text("·").foregroundStyle(.tertiary).fixedSize()
                        Text(port.address.isEmpty ? "*" : port.address).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).layoutPriority(-1)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    if let workingDirectory = port.workingDirectory, workingDirectory != "/" {
                        Label(shortPath(workingDirectory), systemImage: "folder.fill")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 6)
                Button { onToggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .padding(.top, 4)
                stopControl
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isExpanded { details }
        }
        // Keep the summary row anchored; expansion only appends details below it.
        .padding(.vertical, 7)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isExpanded || isHovered) ? Color.accentColor.opacity(0.14) : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            if port.isRootOrSystemProcess {
                systemContextMenu
            } else {
                applicationContextMenu
            }
        }
    }

    @ViewBuilder
    private var systemContextMenu: some View {
        Button("在 Finder 中显示") { revealInFinder() }
            .disabled(port.executableURL == nil)
        Divider()
        Button("复制 localhost:\(port.port)") { copy("localhost:\(port.port)") }
        Button("拷贝 PID") { copy(String(port.pid)) }
        Button("拷贝端口号") { copy(port.port) }
        Divider()
        Button("结束进程") { onStop() }
            .disabled(!port.isOwnedByCurrentUser)
        Button("强制结束 (SIGKILL)") { onForceStop() }
            .disabled(!port.isOwnedByCurrentUser)
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
        Divider()
        Button("结束进程") { onStop() }
            .disabled(!port.isOwnedByCurrentUser)
        Button("强制结束 (SIGKILL)") { onForceStop() }
            .disabled(!port.isOwnedByCurrentUser)
    }

    @ViewBuilder
    private var stopControl: some View {
        if isConfirmingStop {
            VStack(alignment: .trailing, spacing: 3) {
                if port.isRootOrSystemProcess {
                    Text("系统进程受保护")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                } else if port.isLaunchdManaged {
                    Text("结束后会自动重启")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Button {
                    isConfirmingStop = false
                    onStop()
                } label: {
                    Text("结束").font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.red, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(port.isRootOrSystemProcess)
            }
            Button { isConfirmingStop = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("取消")
        } else {
            Button {
                isConfirmingStop = true
            } label: {
                Image(systemName: port.isRootOrSystemProcess ? "lock.circle" : "stop.circle")
            }
            .buttonStyle(.plain).foregroundStyle(port.isOwnedByCurrentUser ? .red : .secondary)
            .help(port.isRootOrSystemProcess ? "系统进程：结束前查看保护提示" : "准备结束进程")
        }
    }

    private var details: some View {
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
        .font(.caption.monospaced())
        .padding(.leading, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func shortPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
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
