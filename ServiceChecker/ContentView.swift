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
    private lazy var aboutWindowController = AboutWindowController()
    @objc private var isMonitoringEnabled: Bool = true {
        didSet {
            viewModel.setMonitoring(enabled: isMonitoringEnabled)
        }
    }
    
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
        
        // Observe changes to rebuild menu and update icon
        viewModel.$services.sink { [weak self] services in
            if let button = self?.statusBarItem.button {
                let upCount = services.filter { $0.status }.count
                self?.updateStatusBarIcon(button: button, upCount: upCount)
            }
            self?.buildMenu()
        }.store(in: &cancellables)
    }
    
    /// Rebuilds the status bar menu with current service statuses
    private func buildMenu() {
        menu.removeAllItems()
        
        // Add monitoring toggle
        let toggleItem = NSMenuItem()
        let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
        
        // Add label on the left
        let monitoringLabel = NSTextField(frame: NSRect(x: 16, y: 0, width: 160, height: 20))
        monitoringLabel.stringValue = "Enable Monitoring"
        monitoringLabel.isEditable = false
        monitoringLabel.isBordered = false
        monitoringLabel.backgroundColor = .clear
        monitoringLabel.textColor = .labelColor
        
        // Add switch on the right
        let checkbox = NSButton(frame: NSRect(x: 200, y: 0, width: 40, height: 20))
        checkbox.title = ""
        checkbox.setButtonType(.switch)
        checkbox.state = isMonitoringEnabled ? .on : .off
        checkbox.target = self
        checkbox.action = #selector(toggleMonitoring)
        
        itemView.addSubview(monitoringLabel)
        itemView.addSubview(checkbox)
        toggleItem.view = itemView
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add services status items
        viewModel.services.forEach { service in
            let menuItem = NSMenuItem()
            let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
            
            let serviceLabel = NSTextField(frame: NSRect(x: 20, y: 0, width: 200, height: 20))
            
            // Change appearance based on monitoring state
            if isMonitoringEnabled {
                let statusSymbol = service.status ? "✅" : "❌"
                let errorText = service.lastError.isEmpty ? "" : " (\(service.lastError))"
                serviceLabel.stringValue = "\(statusSymbol) \(service.name)\(errorText)"
                serviceLabel.textColor = .labelColor
            } else {
                serviceLabel.stringValue = "⦿ \(service.name)"  // or "○" or "•"
                serviceLabel.textColor = .disabledControlTextColor
            }
            
            serviceLabel.isEditable = false
            serviceLabel.isBordered = false
            serviceLabel.backgroundColor = .clear
            serviceLabel.alignment = .left
            
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

        // Add About item
        let aboutItem = NSMenuItem(title: "About ServiceChecker", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

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

    /// Opens the configuration directory in Finder
    @objc private func openConfigDirectory() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let configDirURL = appSupportURL.appendingPathComponent("ServiceChecker")
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configDirURL.path)
    }

    @objc private func showAboutWindow() {
        aboutWindowController.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMonitoring() {
        isMonitoringEnabled.toggle()
        // Update the checkbox state and rebuild menu to update service appearances
        if let toggleItem = menu.items.first,
           let itemView = toggleItem.view,
           let checkbox = itemView.subviews.last as? NSButton {
            checkbox.state = isMonitoringEnabled ? .on : .off
        }
        buildMenu()  // Rebuild entire menu to update service appearances
    }
}

