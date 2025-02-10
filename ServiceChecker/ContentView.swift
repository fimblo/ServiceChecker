//
//  ContentView.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//
import SwiftUI
import AppKit // For NSApplication and NSStatusBarItem

struct ServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    var status: Bool
}

class StatusBarController: NSObject, ObservableObject {
    @Published var services: [ServiceStatus] = [
        ServiceStatus(name: "server 1",
                      url: "http://localhost:8081/health", status: false),
        ServiceStatus(name: "server 2",
                      url: "http://localhost:8085/health", status: false),
        // ... more services
    ]
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!

    override init() {
        super.init()

        DispatchQueue.main.async {
            self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            self.statusBarItem.button?.title = "❓"
            self.statusBarItem.button?.action = #selector(self.toggleMenu)
            self.menu = NSMenu()
            self.statusBarItem.menu = self.menu

            self.updateServiceStatuses() // Initial check
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                self.updateServiceStatuses()
            }
        }
    }

    @objc func toggleMenu() {
        // noop
    }

    func updateServiceStatuses() {
        var upCount = 0 // Store number of UP services

        for index in services.indices {
            let service = services[index]
            let (_, status) = runShellScript(service.url)
            services[index].status = status == 0 ? true : false

            if status == 0 {
                upCount += 1
            }

            buildMenu() // update menu
        }

        let totalCount = services.count
        statusBarItem.button?.title = "LS: \(upCount)/\(totalCount)" // Update title

    }

    func buildMenu() {
        menu.removeAllItems()

        for service in services {
            let menuItem = NSMenuItem(title: "\(service.name): \(service.status)", action: nil, keyEquivalent: "")
            menu.addItem(menuItem)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    }

    func runShellScript(_ url: String) -> (String, Int) {
        // print("runShellScript", url)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl") // Or path to your script
        task.arguments = ["-o", "/dev/null", "-s", "-w", "%{http_code}\\n", url]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            task.waitUntilExit()
            
            if let statusCode = Int(output.trimmingCharacters(in:.whitespacesAndNewlines)), (200...299).contains(statusCode) {
                return ("", 0) // Success (status code in 200-299 range)
            } else {
                return ("", 1) // Failure (any other status code or error)
            }
        } catch {
            print("Error running script: \(error)")
            return ("", 1)
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("This view is not used as we are using the status bar item.")
            .padding()
    }
}
