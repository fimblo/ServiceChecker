//
//  ContentView.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//
import SwiftUI
import AppKit
import Foundation

/// Controls the status bar menu and service monitoring
class StatusBarController: NSObject, ObservableObject {
    @Published var services: [ServiceStatus] = ServiceUtils.loadServicesFromFile()
    @Published var updateInterval: TimeInterval = {
        let savedInterval = UserDefaults.standard.double(forKey: "UpdateInterval")
        return savedInterval > 0 ? savedInterval : 5.0
    }() {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "UpdateInterval")
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
            let (errorMessage, status) = ServiceUtils.checkHealth(service.url)
            DispatchQueue.main.async {
                self.services[index].status = status == 0
                // Store error message if there is one
                if !errorMessage.isEmpty {
                    self.services[index].lastError = errorMessage
                }
            }
            return count + (status == 0 ? 1 : 0)
        }

        // Update the status bar icon
        DispatchQueue.main.async { [weak self] in
            if let button = self?.statusBarItem.button {
                self?.updateStatusBarIcon(button: button, upCount: upCount)
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
            let errorText = service.lastError.isEmpty ? "" : " (\(service.lastError))"
            serviceLabel.stringValue = "\(statusSymbol) \(service.name)\(errorText)"
            serviceLabel.isEditable = false
            serviceLabel.isBordered = false
            serviceLabel.backgroundColor = NSColor.clear
            serviceLabel.alignment = NSTextAlignment.left
            serviceLabel.textColor = NSColor.controlTextColor
            
            itemView.addSubview(serviceLabel)
            menuItem.view = itemView
            menu.addItem(menuItem)
        }

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
        
        // Add separator and preferences
        menu.addItem(NSMenuItem.separator())
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        // Add quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// Converts a slider position (0-12) to seconds (1-60)
    private func sliderPositionToInterval(_ position: Double) -> TimeInterval {
        if position == 0 { return 1 }
        return TimeInterval(position * 5)
    }
    
    /// Converts time interval in seconds to nearest slider position
    private func intervalToSliderPosition(_ interval: TimeInterval) -> Double {
        if interval <= 1 { return 0 }
        return round(interval / 5)
    }
    
    /// Handles slider value changes and updates the UI
    @objc private func sliderChanged(_ sender: NSSlider) {
        let newInterval = sliderPositionToInterval(sender.doubleValue)
        updateInterval = newInterval
        if let label = sender.superview?.subviews.first as? NSTextField {
            label.stringValue = "Update interval: \(Int(newInterval))s"
        }
    }

    /// Updates the status bar icon based on service health
    private func updateStatusBarIcon(button: NSStatusBarButton, upCount: Int) {
        // Create composite image
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let serverImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Server Status")?
            .withSymbolConfiguration(configuration)
        
        let finalImage = NSImage(size: NSSize(width: 18, height: 18))
        finalImage.lockFocus()
        
        // Draw base server icon
        serverImage?.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        
        // Add red warning indicator if any service is down
        if upCount != services.count {
            let statusConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                .applying(.init(paletteColors: [.systemRed]))
            let statusImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(statusConfiguration)
            
            statusImage?.draw(in: NSRect(x: 8, y: 0, width: 10, height: 10))
        }
        
        finalImage.unlockFocus()
        finalImage.isTemplate = false  // Enable colored warning indicator
        
        button.image = finalImage
    }

    @objc private func showPreferences() {
        // Switch to regular mode and activate app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Show settings window
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        
        // Ensure window is visible and active
        if let window = NSApp.windows.first(where: { $0.title.contains("Settings") }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// Main content view
struct ContentView: View {
    @State private var dontShowAgain = UserDefaults.standard.bool(forKey: "HideStartupWindow")
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Service monitoring is active in the status bar.")
                .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration")
                    .font(.headline)
                
                Text("Server names and URLs can be manually configured in:")
                    .padding(.top, 4)
                
                ScrollView {
                    Text("""
                    ~/Library/Containers/org.yanson.ServiceChecker/Data/ \\\\
                        Library/Application Support/ServiceChecker/services.json
                    """)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(height: 60)  // Fixed height to show all content
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                
                Text("Format:")
                    .padding(.top, 4)
                
                ScrollView {
                    Text("""
                    [
                      {
                        "name": "Server name",
                        "url": "http://host:port/path"
                      }
                      // multiple servers supported
                    ]
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                }
                .frame(height: 130)  // Fixed height to show all content
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("Don't show this window at startup", isOn: $dontShowAgain)
                .onChange(of: dontShowAgain) { oldValue, newValue in
                    UserDefaults.standard.set(newValue, forKey: "HideStartupWindow")
                }
            
            Button("Close") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 600)  // Increased width even more
    }
}
