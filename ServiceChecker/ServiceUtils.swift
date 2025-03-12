import Foundation

// Add this new struct at the top level
struct AppConfig {
    /// The default update interval in seconds
    static let DEFAULT_UPDATE_INTERVAL: TimeInterval = 10.0
    /// The default network timeout in seconds
    static let NETWORK_TIMEOUT_SECONDS: TimeInterval = 5
    /// The startup watch duration in seconds (3 minutes)
    static let STARTUP_WATCH_DURATION: TimeInterval = 180.0
    /// The startup watch check interval in seconds
    static let STARTUP_WATCH_INTERVAL: TimeInterval = 1.0
    
    static let DEFAULT_SYMBOL_UP = "🟢"
    static let DEFAULT_SYMBOL_DOWN = "🔴"
    static let DEFAULT_SYMBOL_DISABLED = "⚪"

    var services: [ServiceConfig]
    var updateIntervalSeconds: TimeInterval
    var symbolUp: String
    var symbolDown: String
    var symbolDisabled: String
    
    // Startup watch state
    static var isStartupWatchActive: Bool = false
    static var startupWatchStartTime: Date?
    
    static var shared: AppConfig?
    
    init(services: [ServiceConfig], 
         updateIntervalSeconds: TimeInterval = DEFAULT_UPDATE_INTERVAL,
         symbolUp: String = DEFAULT_SYMBOL_UP,
         symbolDown: String = DEFAULT_SYMBOL_DOWN,
         symbolDisabled: String = DEFAULT_SYMBOL_DISABLED) {
        self.services = services
        self.updateIntervalSeconds = updateIntervalSeconds
        self.symbolUp = symbolUp
        self.symbolDown = symbolDown
        self.symbolDisabled = symbolDisabled
    }
}

// New JSON structure
struct ConfigFile: Codable {
    var services: [ServiceConfig]
    var updateIntervalSeconds: TimeInterval
    var symbolUp: String
    var symbolDown: String
    var symbolDisabled: String
    
    init(services: [ServiceConfig], 
         updateIntervalSeconds: TimeInterval, 
         symbolUp: String = AppConfig.DEFAULT_SYMBOL_UP, 
         symbolDown: String = AppConfig.DEFAULT_SYMBOL_DOWN,
         symbolDisabled: String = AppConfig.DEFAULT_SYMBOL_DISABLED) {
        self.services = services
        self.updateIntervalSeconds = updateIntervalSeconds
        self.symbolUp = symbolUp
        self.symbolDown = symbolDown
        self.symbolDisabled = symbolDisabled
    }
    
    enum CodingKeys: String, CodingKey {
        case services
        case updateIntervalSeconds
        case symbolUp
        case symbolDown
        case symbolDisabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode([ServiceConfig].self, forKey: .services)
        updateIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .updateIntervalSeconds) ?? AppConfig.DEFAULT_UPDATE_INTERVAL
        symbolUp = try container.decodeIfPresent(String.self, forKey: .symbolUp) ?? AppConfig.DEFAULT_SYMBOL_UP
        symbolDown = try container.decodeIfPresent(String.self, forKey: .symbolDown) ?? AppConfig.DEFAULT_SYMBOL_DOWN
        symbolDisabled = try container.decodeIfPresent(String.self, forKey: .symbolDisabled) ?? AppConfig.DEFAULT_SYMBOL_DISABLED
    }
}

class Logger {
    // Static property that's initialized once when the class is first accessed
    static let isVerboseLoggingEnabled: Bool = {
        return ProcessInfo.processInfo.environment["SERVICE_CHECKER_VERBOSE_LOGGING"] != nil
    }()
}

class ServiceUtils {
    /// Checks if a service endpoint is healthy
    /// - Parameter url: The health check URL
    /// - Returns: Tuple of (output string, status code) where 0 means success
    static func checkHealth(_ url: String) -> (String, Int) {
        var originalStderr: Int32 = -1 // placeholder for original stderr file descriptor
        
        if Logger.isVerboseLoggingEnabled {
            originalStderr = dup(FileHandle.standardError.fileDescriptor)
            freopen("/dev/null", "w", stderr)
        }
        
        // Convert localhost to 127.0.0.1 to force IPv4
        // Avoiding ipv6 for non-local connections is out of scope for now - there
        // will be errors in the console if the service is not reachable over ipv6.
        let ipv4Url = url.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        
        guard let serviceURL = URL(string: ipv4Url) else {
            return ("Invalid URL: \(url)", 1)
        }
        
        var result = (output: "", status: 1)
        let semaphore = DispatchSemaphore(value: 0)
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = AppConfig.NETWORK_TIMEOUT_SECONDS
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: serviceURL) { _, response, error in
            defer { semaphore.signal() }
            
            if error != nil {
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                result = ("", 0)
            }
        }
        
        task.resume()
        semaphore.wait()
        
        if Logger.isVerboseLoggingEnabled { // restore if not verbose
            dup2(originalStderr, FileHandle.standardError.fileDescriptor)
            close(originalStderr)
        }
        
        return result
    }
    
    /// Loads service configurations from file into global config
    static func loadConfiguration() -> (Bool, String?) {
        guard let configPath = getConfigPath() else {
            print("Could not determine config path")
            AppConfig.shared = AppConfig(services: getDefaultServices().map { 
                ServiceConfig(name: $0.name, url: $0.url)
            }, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL, symbolUp: AppConfig.DEFAULT_SYMBOL_UP, symbolDown: AppConfig.DEFAULT_SYMBOL_DOWN, symbolDisabled: AppConfig.DEFAULT_SYMBOL_DISABLED)
            return (false, "Could not determine config path")
        }
        
        do {
            let configDir = configPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: configDir,
                                                 withIntermediateDirectories: true)
            
            // Create/overwrite README.txt
            let readmePath = configDir.appendingPathComponent("README.md")
            let readmeContent = """
                # ServiceChecker

                ## Overview
                This is the configuration directory for ServiceChecker; a macOS
                app for monitoring your own services.

                ```
                $ tree
                .
                ├── README.txt     # overwritten at startup. Yes, this file.
                └── config.json    # overwritten on config change.
                ```

                ## Configuration

                `config.json` contains the list of services to monitor and other
                configuration options. Each service should have a name and a health 
                check URL. ServiceChecker assumes that a returning 200 status code
                means the service is up.

                The minimal format is:

                ```json
                {
                    "services": [
                        {
                            "name": "Service Name",
                            "url": "http://localhost",
                        }
                    ]
                }
                ```

                The full format, with all optional fields:

                ```json
                {
                    "services": [
                        {
                            "name": "Service Name",
                            "url": "http://localhost:8080/path/to/health/check",
                            "mode": "enabled",
                        },
                        {
                            "name": "Service Name 2",
                            "url": "http://localhost:8080/path/to/health/check",
                            "mode": "disabled",
                        }
                    ],
                    "symbolUp": "🟢",             /* or any other unicode character */
                    "symbolDown": "🔴",           /* or any other unicode character */
                    "symbolDisabled": "⚪",       /* or any other unicode character */
                    "updateIntervalSeconds": 10   /* 1-60 seconds */
                }
                ```

                You can have multiple services, one after another. I haven't tested
                how many services you can have, but it's probably fun to find out if
                you're into that kind of thing. 

                """
            try readmeContent.write(to: readmePath, atomically: true, encoding: .utf8)
            
            // Create default config if file doesn't exist
            if !FileManager.default.fileExists(atPath: configPath.path) {
                print("Config file doesn't exist, creating with defaults")
                let defaultServices = getDefaultServices()
                let configs = defaultServices.map { ServiceConfig(name: $0.name, url: $0.url) }
                let configFile = ConfigFile(services: configs, updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL, symbolUp: AppConfig.DEFAULT_SYMBOL_UP, symbolDown: AppConfig.DEFAULT_SYMBOL_DOWN, symbolDisabled: AppConfig.DEFAULT_SYMBOL_DISABLED)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                let data = try encoder.encode(configFile)
                try data.write(to: configPath)
                print("Created config file at: \(configPath.path)")
                AppConfig.shared = AppConfig(services: configs, 
                                           updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL,
                                           symbolUp: AppConfig.DEFAULT_SYMBOL_UP,
                                           symbolDown: AppConfig.DEFAULT_SYMBOL_DOWN,
                                           symbolDisabled: AppConfig.DEFAULT_SYMBOL_DISABLED)
                return (true, nil)
            }
            
            print("Reading existing config file")
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            let configFile = try decoder.decode(ConfigFile.self, from: data)
            AppConfig.shared = AppConfig(services: configFile.services, 
                                       updateIntervalSeconds: configFile.updateIntervalSeconds,
                                       symbolUp: configFile.symbolUp,
                                       symbolDown: configFile.symbolDown,
                                       symbolDisabled: configFile.symbolDisabled)
            return (true, nil)
            
        } catch {
            print("Error loading configuration: \(error)")
            AppConfig.shared = AppConfig(services: [], updateIntervalSeconds: AppConfig.DEFAULT_UPDATE_INTERVAL, symbolUp: AppConfig.DEFAULT_SYMBOL_UP, symbolDown: AppConfig.DEFAULT_SYMBOL_DOWN, symbolDisabled: AppConfig.DEFAULT_SYMBOL_DISABLED)
            return (false, "Error parsing config file")
        }
    }

    
    private static func getConfigPath() -> URL? {
        guard let configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return configDir.appendingPathComponent("ServiceChecker/config.json")
    }
    
    private static func getDefaultServices() -> [ServiceStatus] {
        return [
            ServiceStatus(name: "Local Server", url: "http://localhost:8080", status: false)
        ]
    }

    /// Saves the current configuration back to file
    static func saveConfiguration() {
        guard let configPath = getConfigPath(),
              let config = AppConfig.shared else {
            print("Could not save configuration: missing path or config")
            return
        }
        
        do {
            let configFile = ConfigFile(services: config.services, 
                                      updateIntervalSeconds: config.updateIntervalSeconds,
                                      symbolUp: config.symbolUp,
                                      symbolDown: config.symbolDown,
                                      symbolDisabled: config.symbolDisabled)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
            let data = try encoder.encode(configFile)
            try data.write(to: configPath)
            print("Saved configuration to: \(configPath.path)")
        } catch {
            print("Error saving configuration: \(error)")
        }
    }

    /// Starts the Startup Watch mode and notifies observers
    static func startStartupWatch() {
        if !AppConfig.isStartupWatchActive {
            AppConfig.isStartupWatchActive = true
            AppConfig.startupWatchStartTime = Date()
            
            NotificationCenter.default.post(
                name: Notification.Name("StartupWatchStatusChanged"),
                object: nil
            )
            
            print("Startup Watch activated - monitoring services every \(AppConfig.STARTUP_WATCH_INTERVAL) seconds")
        }
    }
    
    /// Stops the Startup Watch mode and notifies observers
    static func stopStartupWatch() {
        if AppConfig.isStartupWatchActive {
            AppConfig.isStartupWatchActive = false
            AppConfig.startupWatchStartTime = nil
            
            NotificationCenter.default.post(
                name: Notification.Name("StartupWatchStatusChanged"),
                object: nil
            )
            
            print("Startup Watch deactivated - returning to normal monitoring")
        }
    }
    
    /// Checks if Startup Watch should be stopped due to timeout or all services up
    static func checkStartupWatchStatus(serviceStatuses: [ServiceStatus]) -> Bool {
        guard AppConfig.isStartupWatchActive,
              let startTime = AppConfig.startupWatchStartTime else {
            return false
        }
        
        // Check if timeout reached (3 minutes)
        let elapsedTime = Date().timeIntervalSince(startTime)
        if elapsedTime >= AppConfig.STARTUP_WATCH_DURATION {
            print("Startup Watch timeout reached (\(AppConfig.STARTUP_WATCH_DURATION) seconds)")
            stopStartupWatch()
            return false
        }
        
        // Check if all services are up (excluding disabled services)
        let enabledServices = serviceStatuses.filter { $0.mode == "enabled" }
        let allServicesUp = enabledServices.allSatisfy { $0.status }
        
        if allServicesUp && !enabledServices.isEmpty {
            print("Startup Watch completed - all services are up")
            stopStartupWatch()
            return false
        }
        
        // else continue
        return true
    }
    
    /// Returns the remaining time for Startup Watch in seconds
    static func getStartupWatchRemainingTime() -> TimeInterval? {
        guard AppConfig.isStartupWatchActive,
              let startTime = AppConfig.startupWatchStartTime else {
            return nil
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = max(0, AppConfig.STARTUP_WATCH_DURATION - elapsedTime)
        return remainingTime
    }
}
