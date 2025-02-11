//
//  ContentView.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//
import SwiftUI
import AppKit // For NSApplication and NSStatusBarItem

/// Represents the status of a single service being monitored
struct ServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    var status: Bool
}

/// Controls the status bar menu and service monitoring
class StatusBarController: NSObject, ObservableObject {
    @Published var services: [ServiceStatus] = getDefaultServices()
    
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!
    private let updateInterval: TimeInterval = 5.0

    override init() {
        super.init()
        DispatchQueue.main.async { [weak self] in
            self?.setupStatusBar()
            self?.startMonitoring()
        }
    }

    /// Sets up the status bar item and menu
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.title = "❓"
        }
        menu = NSMenu()
        statusBarItem.menu = menu
    }

    /// Starts the periodic monitoring of services
    private func startMonitoring() {
        updateServiceStatuses() // Initial check
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateServiceStatuses()
        }
    }

    /// Updates the status of all services and refreshes the menu
    func updateServiceStatuses() {
        let upCount = services.indices.reduce(0) { count, index in
            let service = services[index]
            let (_, status) = checkServiceHealth(service.url)
            DispatchQueue.main.async {
                self.services[index].status = status == 0
            }
            return count + (status == 0 ? 1 : 0)
        }

        DispatchQueue.main.async { [weak self] in
            if let button = self?.statusBarItem.button {
                button.title = "Count:\(upCount)/\(self?.services.count ?? 0)"
            }
            self?.buildMenu()
        }
    }

    /// Rebuilds the status bar menu with current service statuses
    private func buildMenu() {
        menu.removeAllItems()
        
        services.forEach { service in
            let statusSymbol = service.status ? "✅" : "❌"
            let menuItem = NSMenuItem(
                title: "\(statusSymbol) \(service.name)",
                action: nil,
                keyEquivalent: ""
            )
            menu.addItem(menuItem)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// Checks the health of a service endpoint
    /// - Parameter url: The health check URL to query
    /// - Returns: A tuple containing any output string and status code (0 for success)
    private func checkServiceHealth(_ url: String) -> (String, Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        task.arguments = ["-o", "/dev/null", "-s", "-w", "%{http_code}\\n", url]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            task.waitUntilExit()
            
            if let statusCode = Int(output.trimmingCharacters(in:.whitespacesAndNewlines)),
               (200...299).contains(statusCode) {
                return ("", 0)
            }
            return ("", 1)
        } catch {
            print("Error checking service health: \(error)")
            return ("", 1)
        }
    }
}

/// Main content view (unused in this app)
struct ContentView: View {
    var body: some View {
        Text("Service monitoring is active in the status bar.")
            .padding()
    }
}
