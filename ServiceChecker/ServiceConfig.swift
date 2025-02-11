//
//  ServiceConfig.swift
//  ServiceChecker
//

import Foundation

let services: [(String, String)] = [
    ("Server 1", "http://localhost:8081/health"),
    ("Server 2", "http://localhost:8082/health"),
    // more services here
]

/// Creates ServiceStatus objects from service definitions
/// - Returns: An array of ServiceStatus objects initialized with default status
func getDefaultServices() -> [ServiceStatus] {
    return services.map { (name, url) in
        ServiceStatus(name: name, url: url, status: false)
    }
}