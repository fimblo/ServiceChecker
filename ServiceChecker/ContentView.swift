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
    @Published var updateInterval: TimeInterval = 5.0 {
        didSet {
            restartMonitoring()
        }
    }
    private var nextUpdateTime: Date = Date()
    
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!
    private var updateTimer: Timer?

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
            button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Service Status")
            // Optionally set the image to template mode for proper menu bar appearance
            button.image?.isTemplate = true
        }
        menu = NSMenu()
        statusBarItem.menu = menu
    }

    /// Starts the periodic monitoring of services
    private func startMonitoring() {
        updateServiceStatuses() // Initial check
        nextUpdateTime = Date().addingTimeInterval(updateInterval)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateServiceStatuses()
            self?.nextUpdateTime = Date().addingTimeInterval(self?.updateInterval ?? 5.0)
        }
    }

    /// Restarts monitoring with new interval
    private func restartMonitoring() {
        updateTimer?.invalidate()
        startMonitoring()
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

                // Create composite image
                let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                let serverImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Server Status")?
                    .withSymbolConfiguration(configuration)
                
                // Create a new image context
                let finalImage = NSImage(size: NSSize(width: 18, height: 18))
                finalImage.lockFocus()
                
                // Draw server icon (in template mode)
                serverImage?.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                
                // Draw warning indicator if there's a problem
                if upCount != self?.services.count {
                    let statusConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                        .applying(.init(paletteColors: [.systemRed]))
                    let statusImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)?
                        .withSymbolConfiguration(statusConfiguration)
                    
                    statusImage?.draw(in: NSRect(x: 8, y: 0, width: 10, height: 10))
                }
                
                finalImage.unlockFocus()
                finalImage.isTemplate = false  // Allow colors to show
                
                button.image = finalImage
            }
            self?.buildMenu()
        }
    }

    /// Rebuilds the status bar menu with current service statuses
    private func buildMenu() {
        menu.removeAllItems()
        
        // Add next update time
        let timeItem = NSMenuItem()
        let timeView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
        
        let nextUpdateLabel = NSTextField(frame: NSRect(x: 20, y: 0, width: 100, height: 20))
        nextUpdateLabel.stringValue = "Next update:"
        nextUpdateLabel.isEditable = false
        nextUpdateLabel.isBordered = false
        nextUpdateLabel.backgroundColor = NSColor.clear
        nextUpdateLabel.alignment = NSTextAlignment.left
        
        let timeLabel = NSTextField(frame: NSRect(x: 120, y: 0, width: 100, height: 20))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        timeLabel.stringValue = formatter.string(from: nextUpdateTime)
        timeLabel.isEditable = false
        timeLabel.isBordered = false
        timeLabel.backgroundColor = NSColor.clear
        timeLabel.alignment = NSTextAlignment.right
        
        timeView.addSubview(nextUpdateLabel)
        timeView.addSubview(timeLabel)
        
        timeItem.view = timeView
        menu.addItem(timeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add services status items
        services.forEach { service in
            let statusSymbol = service.status ? "✅" : "❌"
            let menuItem = NSMenuItem()
            
            let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
            
            let serviceLabel = NSTextField(frame: NSRect(x: 20, y: 0, width: 200, height: 20))
            serviceLabel.stringValue = "\(statusSymbol) \(service.name)"
            serviceLabel.isEditable = false
            serviceLabel.isBordered = false
            serviceLabel.backgroundColor = NSColor.clear
            serviceLabel.alignment = NSTextAlignment.left
            serviceLabel.textColor = NSColor.controlTextColor  // This should give us the default menu text color
            
            itemView.addSubview(serviceLabel)
            menuItem.view = itemView
            menu.addItem(menuItem)
        }

        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add interval slider
        let sliderItem = NSMenuItem()
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 50))  // Increased width to 240
        
        let label = NSTextField(frame: NSRect(x: 20, y: 30, width: 200, height: 20))  // Increased width to 200
        label.stringValue = "Update interval: \(Int(updateInterval))s"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .center
        
        // Add min/max labels
        let minLabel = NSTextField(frame: NSRect(x: 20, y: 0, width: 20, height: 15))
        minLabel.stringValue = "1s"
        minLabel.isEditable = false
        minLabel.isBordered = false
        minLabel.backgroundColor = .clear
        minLabel.alignment = .left
        
        let maxLabel = NSTextField(frame: NSRect(x: 180, y: 0, width: 40, height: 15))  // Adjusted x position
        maxLabel.stringValue = "60s"
        maxLabel.isEditable = false
        maxLabel.isBordered = false
        maxLabel.backgroundColor = .clear
        maxLabel.alignment = .right
        
        let slider = NSSlider(frame: NSRect(x: 20, y: 15, width: 200, height: 20))  // Increased width to 200
        slider.minValue = 0
        slider.maxValue = 12
        slider.doubleValue = intervalToSliderPosition(updateInterval)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.numberOfTickMarks = 13
        slider.allowsTickMarkValuesOnly = true
        
        sliderView.addSubview(label)
        sliderView.addSubview(slider)
        sliderView.addSubview(minLabel)
        sliderView.addSubview(maxLabel)
        
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        
        // Add separator and quit
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.isEnabled = true
        menu.addItem(quitItem)
    }

    /// Converts slider position to actual interval value
    private func sliderPositionToInterval(_ position: Double) -> TimeInterval {
        if position == 0 { return 1 }
        return TimeInterval(position * 5)
    }
    
    /// Converts interval to nearest slider position
    private func intervalToSliderPosition(_ interval: TimeInterval) -> Double {
        if interval <= 1 { return 0 }
        return round(interval / 5)
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        let newInterval = sliderPositionToInterval(sender.doubleValue)
        updateInterval = newInterval
        if let label = sender.superview?.subviews.first as? NSTextField {
            label.stringValue = "Update interval: \(Int(newInterval))s"
        }
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
