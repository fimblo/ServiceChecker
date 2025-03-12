import Foundation

class StatusBarViewModel: ObservableObject {
    private let config: AppConfig
    @Published var services: [ServiceStatus]
    @Published var updateInterval: TimeInterval
    @Published var configError: String?
    
    // Single timer for all monitoring
    private var monitoringTimer: Timer?
    
    // Published property to notify UI of startup watch status
    @Published var isInStartupWatchMode: Bool = false
    @Published var startupWatchRemainingTime: TimeInterval?
    
    init() {
        print("Initializing StatusBarViewModel...")
        let (success, error) = ServiceUtils.loadConfiguration()
        self.configError = error
        
        self.config = AppConfig.shared ?? AppConfig(services: [], 
                                                  updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
        
        // Only set up services if there's no error
        if success {
            self.services = config.services.map { config in
                let status = ServiceStatus(name: config.name, 
                                         url: config.url, 
                                         status: false, 
                                         lastError: "",
                                         mode: config.mode)
                print("Created ServiceStatus for \(config.name): mode = \(status.mode)")
                return status
            }
        } else {
            self.services = []
        }
        
        self.updateInterval = config.updateIntervalSeconds
        
        if success {
            startMonitoring()
        }
        
        // Add observer for startup watch status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartupWatchStatusChanged),
            name: Notification.Name("StartupWatchStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAllMonitoring()
    }
    
    // Centralized method to handle startup watch status changes
    @objc private func handleStartupWatchStatusChanged() {
        // Update our published property to notify UI
        isInStartupWatchMode = AppConfig.isStartupWatchActive
        
        // Restart monitoring with appropriate interval
        restartMonitoring()
    }
    
    // Centralized method to start/restart monitoring with appropriate interval
    private func restartMonitoring() {
        stopAllMonitoring()
        
        if !isMonitoringEnabled() {
            return
        }
        
        // Determine the appropriate interval based on mode
        let interval = isInStartupWatchMode ? 
            AppConfig.STARTUP_WATCH_INTERVAL : updateInterval
        
        // Start with an immediate check
        _ = updateServiceStatuses()
        
        // Create a single timer with the appropriate interval
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Update services
            _ = self.updateServiceStatuses()
            
            // If in startup watch mode, check if we should continue
            if self.isInStartupWatchMode {
                // Update remaining time for UI
                if let remainingTime = ServiceUtils.getStartupWatchRemainingTime() {
                    self.startupWatchRemainingTime = remainingTime
                }
                
                // Check if we should continue startup watch
                let shouldContinue = ServiceUtils.checkStartupWatchStatus(serviceStatuses: self.services)
                
                if !shouldContinue {
                    // Startup watch has ended (either timeout or all services up)
                    // The notification handler will restart normal monitoring
                }
            }
        }
    }
    
    /// Starts the periodic monitoring of services
    private func startMonitoring() {
        restartMonitoring()
    }
    
    /// Stops all monitoring timers
    private func stopAllMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// Updates the interval and restarts monitoring
    func updateInterval(_ newInterval: TimeInterval) {
        updateInterval = newInterval
        if AppConfig.shared != nil {
            AppConfig.shared?.updateIntervalSeconds = newInterval
            ServiceUtils.saveConfiguration()
        }
        restartMonitoring()
    }
    
    /// Updates the status of all services
    func updateServiceStatuses() -> Int {
        let upCount = services.indices.reduce(into: 0) { count, index in
            let service = services[index]
            // Only check health if the service is in enabled mode
            if service.mode == "enabled" {
                let (errorMessage, status) = ServiceUtils.checkHealth(service.url)
                DispatchQueue.main.async {
                    self.services[index].status = status == 0
                    if !errorMessage.isEmpty {
                        self.services[index].lastError = errorMessage
                    }
                }
                count += (status == 0 ? 1 : 0)
            }
        }
        return upCount
    }
    
    /// Helper to check if monitoring is enabled
    private func isMonitoringEnabled() -> Bool {
        // We can add more complex logic here if needed
        return true
    }
    
    /// Public method to enable/disable monitoring
    func setMonitoring(enabled: Bool) {
        if enabled {
            startMonitoring()
        } else {
            stopAllMonitoring()
        }
    }
    
    /// Reloads the configuration from disk and updates the view model
    func reloadConfiguration() {
        let (success, error) = ServiceUtils.loadConfiguration()
        self.configError = error
        
        if success, let newConfig = AppConfig.shared {
            self.services = newConfig.services.map { config in
                ServiceStatus(name: config.name, url: config.url, status: false, lastError: "", mode: config.mode)
            }
            self.updateInterval = newConfig.updateIntervalSeconds
            
            // Update startup watch status
            self.isInStartupWatchMode = AppConfig.isStartupWatchActive
            
            // Restart monitoring with appropriate settings
            restartMonitoring()
        } else {
            self.services = []
            stopAllMonitoring()
        }
    }
    
    /// Manually toggle startup watch mode
    func toggleStartupWatch() {
        if AppConfig.isStartupWatchActive {
            ServiceUtils.stopStartupWatch()
        } else {
            ServiceUtils.startStartupWatch()
        }
        // The notification handler will take care of updating timers
    }
} 
