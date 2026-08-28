//
//  RunStatApp.swift
//  RunStat
//
//  Created by OSpoon on 2026/8/27.
//

import AppKit
import SwiftUI

@main
struct RunStatApp: App {
    @StateObject private var monitor = PortMonitor()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ContentView(monitor: monitor)
        } label: {
            Label {
                Text(monitor.listeningPorts.isEmpty ? "RunStat" : "RunStat · \(monitor.listeningPorts.count)")
            } icon: {
                Image(systemName: "dot.radiowaves.left.and.right")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
