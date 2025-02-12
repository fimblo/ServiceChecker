import Foundation

class StatusBarViewModel: ObservableObject {
    @Published var services: [ServiceStatus] = ServiceUtils.loadServicesFromFile()
    @Published var updateInterval: TimeInterval = {
        let savedInterval = UserDefaults.standard.double(forKey: "UpdateInterval")
        return savedInterval > 0 ? savedInterval : 5.0
    }()
    
    @Published var nextUpdateTime: Date = Date()
    private var updateTimer: Timer?
    
    init() {
        startMonitoring()
    }
    
    /// Starts the periodic monitoring of services
    func startMonitoring() {
        _ = updateServiceStatuses() // Initial check
        nextUpdateTime = Date().addingTimeInterval(updateInterval)
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            _ = self?.updateServiceStatuses()
            self?.nextUpdateTime = Date().addingTimeInterval(self?.updateInterval ?? 5.0)
        }
    }
    
    /// Updates the interval and restarts monitoring
    func updateInterval(_ newInterval: TimeInterval) {
        updateInterval = newInterval
        UserDefaults.standard.set(updateInterval, forKey: "UpdateInterval")
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
    
    /// Converts a slider position (0-12) to seconds (1-60)
    func sliderPositionToInterval(_ position: Double) -> TimeInterval {
        if position == 0 { return 1 }
        return TimeInterval(position * 5)
    }
    
    /// Converts time interval in seconds to nearest slider position
    func intervalToSliderPosition(_ interval: TimeInterval) -> Double {
        if interval <= 1 { return 0 }
        return round(interval / 5)
    }
    
    deinit {
        updateTimer?.invalidate()
    }
} 
