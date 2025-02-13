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
        
        // Add update interval info
        let intervalInfoItem = NSMenuItem()
        let intervalView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
        
        let intervalLabel = NSTextField(frame: NSRect(x: 16, y: 0, width: 200, height: 20))
        intervalLabel.stringValue = "Update interval: \(Int(viewModel.updateInterval)) seconds"
        intervalLabel.isEditable = false
        intervalLabel.isBordered = false
        intervalLabel.backgroundColor = .clear
        intervalLabel.textColor = .secondaryLabelColor
        
        intervalView.addSubview(intervalLabel)
        intervalInfoItem.view = intervalView
        menu.addItem(intervalInfoItem)
        
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
        
        // Create Configure submenu
        let configureMenu = NSMenu()
        configureMenu.autoenablesItems = false

        // Create Update Interval submenu
        let intervalMenu = NSMenu()
        let intervalItem = NSMenuItem(title: "Update Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu

        // Add interval options
        let intervals = [1, 5, 10, 30, 60]
        intervals.forEach { seconds in
            let item = NSMenuItem(
                title: "\(seconds) seconds",
                action: #selector(updateInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = seconds
            item.state = seconds == Int(viewModel.updateInterval) ? .on : .off
            intervalMenu.addItem(item)
        }

        configureMenu.addItem(intervalItem)

        // Add Reload Configuration option
        let reloadConfigItem = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfiguration), keyEquivalent: "r")
        reloadConfigItem.target = self
        configureMenu.addItem(reloadConfigItem)

        // Add Open Config Directory to the submenu
        let openConfigItem = NSMenuItem(title: "Open Config Directory", action: #selector(openConfigDirectory), keyEquivalent: "")
        openConfigItem.target = self
        configureMenu.addItem(openConfigItem)

        // Add the Configure menu item with submenu
        let configureItem = NSMenuItem(title: "Configure", action: nil, keyEquivalent: "")
        configureItem.submenu = configureMenu
        menu.addItem(configureItem)

        // Add About and Quit items
        let aboutItem = NSMenuItem(title: "About ServiceChecker", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// Updates the status bar icon based on service health
    private func updateStatusBarIcon(button: NSStatusBarButton, upCount: Int) {
        // Create composite image
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        
        // Choose icon color based on monitoring state
        let serverConfiguration: NSImage.SymbolConfiguration
        if isMonitoringEnabled {
            serverConfiguration = configuration
        } else {
            serverConfiguration = configuration.applying(.init(paletteColors: [.secondaryLabelColor]))
        }
        
        let serverImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Server Status")?
            .withSymbolConfiguration(serverConfiguration)
        
        let finalImage = NSImage(size: NSSize(width: 18, height: 18))
        finalImage.lockFocus()
        
        // Draw base server icon
        serverImage?.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        
        // Add red warning indicator only if monitoring is enabled and there are down services
        if isMonitoringEnabled && upCount != viewModel.services.count {
            let statusConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                .applying(.init(paletteColors: [.systemRed]))
            let statusImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(statusConfiguration)
            
            statusImage?.draw(in: NSRect(x: 8, y: 0, width: 10, height: 10))
        }
        
        finalImage.unlockFocus()
        finalImage.isTemplate = false
        
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
        // Update the checkbox state
        if let toggleItem = menu.items.first,
           let itemView = toggleItem.view,
           let checkbox = itemView.subviews.last as? NSButton {
            checkbox.state = isMonitoringEnabled ? .on : .off
        }
        
        // Explicitly update the status bar icon
        if let button = statusBarItem.button {
            let upCount = viewModel.services.filter { $0.status }.count
            updateStatusBarIcon(button: button, upCount: upCount)
        }
        
        buildMenu()  // Rebuild menu to update service appearances
    }

    // Add this method to handle interval selection
    @objc private func updateInterval(_ sender: NSMenuItem) {
        viewModel.updateInterval(Double(sender.tag))
        
        // Update radio button states
        if let intervalMenu = sender.menu {
            for item in intervalMenu.items {
                item.state = (item == sender) ? .on : .off
            }
        }
    }

    @objc private func reloadConfiguration() {
        ServiceUtils.loadConfiguration()
        viewModel.reloadConfiguration()
        
        // Force menu rebuild to update statuses
        buildMenu()
        
        // Explicitly update the status bar icon
        if let button = statusBarItem.button {
            let upCount = viewModel.services.filter { $0.status }.count
            updateStatusBarIcon(button: button, upCount: upCount)
        }
        
        // Update the interval menu items to reflect any changes
        if let configureItem = menu.items.first(where: { $0.title == "Configure" }),
           let configureMenu = configureItem.submenu,
           let intervalItem = configureMenu.items.first(where: { $0.title == "Update Interval" }),
           let intervalMenu = intervalItem.submenu {
            for item in intervalMenu.items {
                item.state = item.tag == Int(viewModel.updateInterval) ? .on : .off
            }
        }
    }
}

