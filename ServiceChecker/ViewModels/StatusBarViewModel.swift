import Foundation

class StatusBarViewModel: ObservableObject {
    private let config: AppConfig
    @Published var services: [ServiceStatus]
    @Published var updateInterval: TimeInterval
    @Published var configError: String?
    private var updateTimer: Timer?
    
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
    }
    
    /// Starts the periodic monitoring of services
    private func startMonitoring() {
        _ = updateServiceStatuses() // Initial check
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            _ = self?.updateServiceStatuses()
        }
    }
    
    /// Updates the interval and restarts monitoring
    func updateInterval(_ newInterval: TimeInterval) {
        updateInterval = newInterval
        if AppConfig.shared != nil {
            AppConfig.shared?.updateIntervalSeconds = newInterval
            ServiceUtils.saveConfiguration()
        }
        startMonitoring()
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
    
    func setMonitoring(enabled: Bool) {
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Reloads the configuration from disk and updates the view model
    func reloadConfiguration() {
        let (success, error) = ServiceUtils.loadConfiguration()
        self.configError = error
        
        if success, let newConfig = AppConfig.shared {
            self.services = newConfig.services.map { config in
                ServiceStatus(name: config.name, url: config.url, status: false, lastError: "")
            }
            self.updateInterval = newConfig.updateIntervalSeconds
            startMonitoring()
        } else {
            self.services = []
            stopMonitoring()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
} 
