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
class StatusBarController: NSObject, ObservableObject, NSMenuDelegate {
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
    
    private var menuUpdateTimer: Timer?
    
    override init() {
        self.viewModel = StatusBarViewModel()
        super.init()
        
        // Sync the initial monitoring state with the view model
        viewModel.monitoringEnabled = isMonitoringEnabled
        
        DispatchQueue.main.async { [weak self] in
            self?.setupStatusBar()
        }
        
        // Update icon when config error status changes
        viewModel.$configError.sink { [weak self] _ in
            guard let self = self,
                  let button = self.statusBarItem?.button else { return }
            
            let upCount = self.viewModel.services.filter { $0.status && $0.mode == "enabled" }.count
            self.updateStatusBarIcon(button: button, upCount: upCount)
        }.store(in: &cancellables)
        
        // Observe startup watch status changes
        viewModel.$isInStartupWatchMode.sink { [weak self] _ in
            self?.buildMenu()
        }.store(in: &cancellables)
        
        // Observe remaining time changes to update the menu
        viewModel.$startupWatchRemainingTime.sink { [weak self] _ in
            if self?.viewModel.isInStartupWatchMode == true {
                self?.buildMenu()
            }
        }.store(in: &cancellables)
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
        menu.delegate = self  // Set the delegate
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
        // Check if menu is initialized
        guard menu != nil else {
            print("Warning: Attempted to build menu before it was initialized")
            return
        }
        
        menu.removeAllItems()
        
        // Add monitoring toggle
        let toggleItem = NSMenuItem()
        toggleItem.tag = -1  // Use a tag that won't conflict with service indices
        let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
        
        // Adjust y-coordinate of the label to better align with the checkbox
        let monitoringLabel = NSTextField(frame: NSRect(x: 16, y: 2, width: 160, height: 16))
        monitoringLabel.stringValue = "Enable Monitoring"
        monitoringLabel.isEditable = false
        monitoringLabel.isBordered = false
        monitoringLabel.backgroundColor = .clear
        monitoringLabel.textColor = .labelColor
        
        // Keep checkbox at same position
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
        
        // Add Startup Watch button if monitoring is enabled
        if isMonitoringEnabled {
            let startupWatchItem = NSMenuItem()
            let startupWatchView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
            
            // Create label with same positioning as monitoring label
            let startupWatchLabel = NSTextField(frame: NSRect(x: 16, y: 2, width: 160, height: 16))
            
            // Include the countdown in the label if in startup watch mode
            if viewModel.isInStartupWatchMode, let remainingTime = viewModel.startupWatchRemainingTime {
                let minutes = Int(remainingTime) / 60
                let seconds = Int(remainingTime) % 60
                startupWatchLabel.stringValue = "Startup Watch: \(minutes)m \(seconds)s"
            } else {
                startupWatchLabel.stringValue = "Startup Watch"
            }
            
            startupWatchLabel.isEditable = false
            startupWatchLabel.isBordered = false
            startupWatchLabel.backgroundColor = .clear
            startupWatchLabel.textColor = .labelColor
            
            // Create checkbox with same positioning as monitoring checkbox
            let startupWatchCheckbox = NSButton(frame: NSRect(x: 200, y: 0, width: 40, height: 20))
            startupWatchCheckbox.title = ""
            startupWatchCheckbox.setButtonType(.switch)
            startupWatchCheckbox.state = viewModel.isInStartupWatchMode ? .on : .off
            startupWatchCheckbox.target = self
            startupWatchCheckbox.action = #selector(toggleStartupWatch)
            
            startupWatchView.addSubview(startupWatchLabel)
            startupWatchView.addSubview(startupWatchCheckbox)
            startupWatchItem.view = startupWatchView
            menu.addItem(startupWatchItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Show error message if there is one
        if let error = viewModel.configError {
            let errorItem = NSMenuItem()
            let errorView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 40))
            
            let errorLabel = NSTextField(frame: NSRect(x: 16, y: -13, width: 200, height: 40))
            errorLabel.stringValue = "⚠️ \(error)"
            errorLabel.isEditable = false
            errorLabel.isBordered = false
            errorLabel.backgroundColor = .clear
            errorLabel.textColor = .systemRed
            errorLabel.cell?.wraps = true
            
            errorView.addSubview(errorLabel)
            errorItem.view = errorView
            menu.addItem(errorItem)
        } else {
            // Add interval info item only if not in startup watch mode
            if !viewModel.isInStartupWatchMode {
                let intervalInfoItem = NSMenuItem()
                let intervalView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
                
                let intervalLabel = NSTextField(frame: NSRect(x: 16, y: 0, width: 200, height: 20))
                intervalLabel.stringValue = "Update interval: \(Int(viewModel.updateInterval)) seconds"
                intervalLabel.isEditable = false
                intervalLabel.isBordered = false
                intervalLabel.backgroundColor = .clear
                intervalLabel.textColor = .labelColor
                
                intervalView.addSubview(intervalLabel)
                intervalInfoItem.view = intervalView
                menu.addItem(intervalInfoItem)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // Add services status items
            viewModel.services.enumerated().forEach { (index, service) in
                let menuItem = NSMenuItem(title: service.name, action: #selector(toggleServiceMode(_:)), keyEquivalent: "")
                menuItem.tag = index
                menuItem.target = self
                
                // Create the custom view
                let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
                
                let serviceLabel = NSTextField(frame: NSRect(x: 16, y: 0, width: 200, height: 20))
                serviceLabel.isEditable = false
                serviceLabel.isBordered = false
                serviceLabel.backgroundColor = .clear
                serviceLabel.alignment = .left
                
                // Set the appearance based on monitoring and service mode
                if isMonitoringEnabled {
                    if service.mode == "enabled" {
                        let statusSymbol = service.status ? 
                            AppConfig.shared?.symbolUp ?? AppConfig.DEFAULT_SYMBOL_UP : 
                            AppConfig.shared?.symbolDown ?? AppConfig.DEFAULT_SYMBOL_DOWN
                        let errorText = service.lastError.isEmpty ? "" : " (\(service.lastError))"
                        serviceLabel.stringValue = "\(statusSymbol) \(service.name)\(errorText)"
                        serviceLabel.textColor = .labelColor
                    } else {
                        let disabledSymbol = AppConfig.shared?.symbolDisabled ?? AppConfig.DEFAULT_SYMBOL_DISABLED
                        serviceLabel.stringValue = "\(disabledSymbol) \(service.name)"
                        serviceLabel.textColor = .disabledControlTextColor
                    }
                } else {
                    let disabledSymbol = AppConfig.shared?.symbolDisabled ?? AppConfig.DEFAULT_SYMBOL_DISABLED
                    serviceLabel.stringValue = "\(disabledSymbol) \(service.name)"
                    serviceLabel.textColor = .disabledControlTextColor
                }
                
                itemView.addSubview(serviceLabel)
                menuItem.view = itemView
                
                // Make the menu item clickable
                let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(toggleServiceMode(_:)))
                itemView.addGestureRecognizer(clickGesture)
                
                menu.addItem(menuItem)
            }
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
        let serverImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Service Status")!
        serverImage.size = NSSize(width: 18, height: 18)
        
        // Create a new image that will contain both the server rack and the overlay
        let compositeImage = NSImage(size: NSSize(width: 18, height: 18))
        compositeImage.lockFocus()
        // Image is a template; thus MAC OS will apply the colors based on system light/dark modes
        compositeImage.isTemplate = true;
        
        if !isMonitoringEnabled {
            // Greyed out server rack for disabled monitoring
            NSColor.disabledControlTextColor.set()
            serverImage.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18),
                            from: NSRect(x: 0, y: 0, width: 18, height: 18),
                            operation: .sourceOver,
                            fraction: 0.5)
        } else {
            // Normal color server rack
            serverImage.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            
            if viewModel.configError != nil {
                // Draw the X for config error
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.red,
                    .font: NSFont.systemFont(ofSize: 20, weight: .bold)
                ]
                let x = "×"
                let xSize = x.size(withAttributes: attributes)
                let xPoint = NSPoint(
                    x: (18 - xSize.width) / 2,
                    y: (18 - xSize.height) / 2
                )
                x.draw(at: xPoint, withAttributes: attributes)
            } else {
      
            }
        }
        
        compositeImage.unlockFocus()
        
        button.image = compositeImage
        button.attributedTitle = NSAttributedString()
        
        // Overlay red indicator
        let redDot = NSView(frame: NSRect(x: button.frame.width - 12, y: button.frame.height - 6, width: 6, height: 6))
        redDot.wantsLayer = true
        redDot.layer?.cornerRadius = 3 // Rounded red dot
        redDot.layer?.backgroundColor = NSColor.red.cgColor // Red color
        redDot.identifier = NSUserInterfaceItemIdentifier("redDot")

        let found = button.subviews.first(where: {
            $0.identifier?.rawValue == "redDot"
        })
        var allServicesAreUp = true
        
        if isMonitoringEnabled {
            // Check status of enabled services only
            let enabledServices = viewModel.services.filter { $0.mode == "enabled" }
            if !enabledServices.isEmpty {
                let allUp = enabledServices.allSatisfy { $0.status }
                if !allUp{
                    allServicesAreUp = false
                    if (found == nil) {
                        button.addSubview(redDot)
                    }
                }
            }
        }
        
        if allServicesAreUp && (found != nil){
            found?.removeFromSuperview()
        }
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

    @objc public func toggleServiceMode(_ sender: Any) {
        let index: Int
        if let menuItem = sender as? NSMenuItem {
            index = menuItem.tag
        } else if let gesture = sender as? NSClickGestureRecognizer,
                  let view = gesture.view,
                  let menuItem = menu.items.first(where: { $0.view === view }) {
            index = menuItem.tag
        } else {
            return
        }
        
        if index < viewModel.services.count {
            var updatedServices = viewModel.services
            let currentMode = updatedServices[index].mode
            updatedServices[index].mode = currentMode == "enabled" ? "disabled" : "enabled"
            viewModel.services = updatedServices
            
            // Update config and save
            if var config = AppConfig.shared {
                var services = config.services
                services[index].mode = updatedServices[index].mode
                config = AppConfig(
                    services: services, 
                    updateIntervalSeconds: config.updateIntervalSeconds,
                    symbolUp: config.symbolUp,
                    symbolDown: config.symbolDown,
                    symbolDisabled: config.symbolDisabled
                )
                AppConfig.shared = config
                ServiceUtils.saveConfiguration()
            }
            
            buildMenu()
            
            // Explicitly update the status bar icon
            if let button = statusBarItem.button {
                let upCount = viewModel.services.filter { $0.status }.count
                updateStatusBarIcon(button: button, upCount: upCount)
            }
        }
    }

    @objc private func toggleStartupWatch() {
        viewModel.toggleStartupWatch()
    }

    // MARK: - NSMenuDelegate methods
    
    func menuWillOpen(_ menu: NSMenu) {
        // Stop any existing timer
        menuUpdateTimer?.invalidate()
        menuUpdateTimer = nil
        
        // Use a longer interval (1 second) to reduce flickering
        menuUpdateTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenuItemsWhileOpen()
        }
        
        if let timer = menuUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menuUpdateTimer?.invalidate()
        menuUpdateTimer = nil
    }
    
    /// Updates specific menu items without rebuilding the entire menu
    private func updateMenuItemsWhileOpen() {
        // Only update the countdown timer text
        if viewModel.isInStartupWatchMode, 
           let remainingTime = viewModel.startupWatchRemainingTime,
           let startupWatchItem = menu.items.first(where: { 
               $0.view?.subviews.first is NSTextField && 
               ($0.view?.subviews.first as? NSTextField)?.stringValue.contains("Startup Watch") == true 
           }),
           let startupWatchView = startupWatchItem.view,
           let startupWatchLabel = startupWatchView.subviews.first as? NSTextField {
            
            // Update the remaining time in the view model
            viewModel.updateStartupWatchRemainingTime()
            
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            startupWatchLabel.stringValue = "Startup Watch: \(minutes)m \(seconds)s"
        }
        
        // Update the status bar icon only
        if let button = statusBarItem.button {
            let upCount = viewModel.services.filter { $0.status && $0.mode == "enabled" }.count
            updateStatusBarIcon(button: button, upCount: upCount)
        }
        
        // DO NOT update service items while menu is open - this causes duplication
        // Users will need to close and reopen the menu to see service status changes
    }
}

// Add this extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

