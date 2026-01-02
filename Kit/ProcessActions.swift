//
//  ProcessActions.swift
//  Kit
//
//  Created for Stats fork
//  Adds right-click context menu actions for process management
//

import Cocoa

// MARK: - Process Action Types

public enum ProcessAction {
    case quit
    case forceQuit
    case restart
}

// MARK: - Process Action Handler

public class ProcessActionHandler {

    public static let shared = ProcessActionHandler()

    private init() {}

    // MARK: - Public Actions

    /// Quit a process gracefully
    public func quit(pid: Int) {
        asyncShell("kill \(pid)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshModules()
        }
    }

    /// Force quit a process immediately
    public func forceQuit(pid: Int) {
        asyncShell("kill -9 \(pid)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshModules()
        }
    }

    /// Restart a process: graceful quit with 5s timeout, then force quit if needed, then relaunch
    public func restart(pid: Int, appName: String) {
        // Get the bundle path before killing the process
        let bundlePath = self.getAppBundlePath(pid: pid)

        // Try graceful quit first
        asyncShell("kill \(pid)")

        // Monitor for termination with 5 second timeout
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let startTime = Date()
            let timeout: TimeInterval = 5.0

            // Poll until process is gone or timeout
            while Date().timeIntervalSince(startTime) < timeout {
                if !self.isProcessRunning(pid: pid) {
                    // Process terminated gracefully
                    self.relaunchApp(bundlePath: bundlePath, appName: appName)
                    return
                }
                Thread.sleep(forTimeInterval: 0.25)
            }

            // Timeout reached, force quit
            asyncShell("kill -9 \(pid)")
            Thread.sleep(forTimeInterval: 0.5)

            // Relaunch the app
            self.relaunchApp(bundlePath: bundlePath, appName: appName)
        }
    }

    // MARK: - Private Helpers

    private func isProcessRunning(pid: Int) -> Bool {
        let output = syncShell("ps -p \(pid) -o pid=").trimmingCharacters(in: .whitespacesAndNewlines)
        return !output.isEmpty
    }

    private func getAppBundlePath(pid: Int) -> String? {
        // Try to get the .app bundle path using lsappinfo
        let output = syncShell("lsappinfo info -only bundlepath -app \(pid) 2>/dev/null")

        // Parse the output - format is: "bundlepath"="/path/to/App.app"
        if let range = output.range(of: "\"bundlepath\"=\"") {
            let pathStart = output[range.upperBound...]
            if let endQuote = pathStart.firstIndex(of: "\"") {
                return String(pathStart[..<endQuote])
            }
        }

        return nil
    }

    private func relaunchApp(bundlePath: String?, appName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if let path = bundlePath {
                // Use the exact bundle path if available
                asyncShell("open \"\(path)\"")
            } else {
                // Fall back to app name
                asyncShell("open -a \"\(appName)\"")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.refreshModules()
            }
        }
    }

    private func refreshModules() {
        // Refresh modules that display process lists
        for moduleName in ["RAM", "CPU"] {
            NotificationCenter.default.post(name: .refreshModule, object: nil, userInfo: ["module": moduleName])
        }
    }
}

// MARK: - Context Menu Builder

public class ProcessContextMenu {

    /// Creates a context menu for process actions
    public static func create(pid: Int, appName: String) -> NSMenu {
        let menu = NSMenu()

        let context = ProcessMenuContext(pid: pid, appName: appName)

        // Restart item
        let restartItem = NSMenuItem(
            title: localizedString("Restart"),
            action: #selector(ProcessMenuTarget.restart(_:)),
            keyEquivalent: ""
        )
        restartItem.representedObject = context
        restartItem.target = ProcessMenuTarget.shared
        menu.addItem(restartItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(
            title: localizedString("Quit"),
            action: #selector(ProcessMenuTarget.quit(_:)),
            keyEquivalent: ""
        )
        quitItem.representedObject = context
        quitItem.target = ProcessMenuTarget.shared
        menu.addItem(quitItem)

        // Force Quit item
        let forceQuitItem = NSMenuItem(
            title: localizedString("Force Quit"),
            action: #selector(ProcessMenuTarget.forceQuit(_:)),
            keyEquivalent: ""
        )
        forceQuitItem.representedObject = context
        forceQuitItem.target = ProcessMenuTarget.shared
        menu.addItem(forceQuitItem)

        return menu
    }
}

// MARK: - Menu Context

private struct ProcessMenuContext {
    let pid: Int
    let appName: String
}

// MARK: - Menu Target

private class ProcessMenuTarget: NSObject {
    static let shared = ProcessMenuTarget()

    @objc func quit(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProcessMenuContext else { return }
        ProcessActionHandler.shared.quit(pid: context.pid)
    }

    @objc func forceQuit(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProcessMenuContext else { return }
        ProcessActionHandler.shared.forceQuit(pid: context.pid)
    }

    @objc func restart(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProcessMenuContext else { return }
        ProcessActionHandler.shared.restart(pid: context.pid, appName: context.appName)
    }
}
