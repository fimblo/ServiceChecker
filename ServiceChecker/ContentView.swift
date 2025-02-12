//
//  ContentView.swift
//  ServiceChecker
//
//  Created by fimblo on 2025-02-10.
//
import SwiftUI
import AppKit
import Foundation
import Combine

/// Controls the status bar menu and service monitoring
class StatusBarController: NSObject, ObservableObject {
    private let viewModel: StatusBarViewModel
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.viewModel = StatusBarViewModel()
        super.init()
        
        DispatchQueue.main.async { [weak self] in
            self?.setupStatusBar()
        }
    }
    
    /// Sets up the status bar item and menu
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Service Status")?
                .withSymbolConfiguration(configuration)
            button.imagePosition = .imageLeft
            //button.imageScaling = .scaleProportionallyDown
        }
        menu = NSMenu()
        statusBarItem.menu = menu
        
        // Observe changes to rebuild menu
        viewModel.$services.sink { [weak self] _ in
            self?.buildMenu()
        }.store(in: &cancellables)
        
        viewModel.$nextUpdateTime.sink { [weak self] _ in
            self?.buildMenu()
        }.store(in: &cancellables)
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
        timeLabel.stringValue = formatter.string(from: viewModel.nextUpdateTime)
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
        viewModel.services.forEach { service in
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
        label.stringValue = "Update interval: \(Int(viewModel.updateInterval))s"
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
        slider.doubleValue = viewModel.intervalToSliderPosition(viewModel.updateInterval)
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
        
        // Add separator and config directory
        menu.addItem(NSMenuItem.separator())
        
        // Add Open Config Directory item
        let openConfigItem = NSMenuItem(title: "Open Config Directory", action: #selector(openConfigDirectory), keyEquivalent: "")
        openConfigItem.target = self
        menu.addItem(openConfigItem)
        
        // Add quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// Handles slider value changes and updates the UI
    @objc private func sliderChanged(_ sender: NSSlider) {
        let newInterval = viewModel.sliderPositionToInterval(sender.doubleValue)
        viewModel.updateInterval(newInterval)
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
        if upCount != viewModel.services.count {
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

    /// Opens the configuration directory in Finder
    @objc private func openConfigDirectory() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let configDirURL = appSupportURL.appendingPathComponent("ServiceChecker")
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configDirURL.path)
    }
}

/// Main content view
struct ContentView: View {
    var body: some View {
        Text("Service monitoring is active in the status bar.")
            .padding()
            .frame(width: 300)
    }
}
