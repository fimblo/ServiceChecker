import Foundation

class StatusBarViewModel: ObservableObject {
    private let config: AppConfig
    @Published var services: [ServiceStatus]
    @Published var updateInterval: TimeInterval
    private var updateTimer: Timer?
    
    init() {
        ServiceUtils.loadConfiguration()
        self.config = AppConfig.shared ?? AppConfig(services: [], 
                                                  updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL)
        
        self.services = config.services.map { config in
            ServiceStatus(name: config.name, url: config.url, status: false)
        }
        
        self.updateInterval = config.updateIntervalSeconds
        
        startMonitoring()
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
            let (errorMessage, status) = ServiceUtils.checkHealth(service.url)
            DispatchQueue.main.async {
                self.services[index].status = status == 0
                if !errorMessage.isEmpty {
                    self.services[index].lastError = errorMessage
                }
            }
            count += (status == 0 ? 1 : 0)
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
    
    deinit {
        updateTimer?.invalidate()
    }
} 
