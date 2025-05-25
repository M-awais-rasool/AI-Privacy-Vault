import Foundation
import SwiftUI

class AuditLogger {
    static let shared = AuditLogger()
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsDirectory.appendingPathComponent("vault_audit_log.json")
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let initialLog: [[String: Any]] = []
            try? JSONSerialization.data(withJSONObject: initialLog)
                .write(to: logFileURL)
        }
    }
    
    func logEvent(type: AuditEventType, fileURL: URL? = nil, details: String) {
        var logEntry: [String: Any] = [
            "timestamp": dateFormatter.string(from: Date()),
            "eventType": type.rawValue,
            "details": details
        ]
        
        if let fileURL = fileURL {
            logEntry["filename"] = fileURL.lastPathComponent
        }
        
        do {
            let logData = try Data(contentsOf: logFileURL)
            var logs = try JSONSerialization.jsonObject(with: logData) as! [[String: Any]]
            
            logs.append(logEntry)
            
            let updatedLogData = try JSONSerialization.data(withJSONObject: logs, options: [.prettyPrinted])
            try updatedLogData.write(to: logFileURL)
        } catch {
            print("Failed to update audit log: \(error)")
        }
    }
    
    func getAuditLogs() -> [AuditEvent] {
        do {
            let logData = try Data(contentsOf: logFileURL)
            let logs = try JSONSerialization.jsonObject(with: logData) as! [[String: Any]]
            
            return logs.compactMap { entry in
                guard 
                    let timestampString = entry["timestamp"] as? String,
                    let eventTypeString = entry["eventType"] as? String,
                    let eventType = AuditEventType(rawValue: eventTypeString),
                    let details = entry["details"] as? String
                else {
                    return nil
                }
                
                let filename = entry["filename"] as? String
                
                return AuditEvent(
                    timestamp: dateFormatter.date(from: timestampString) ?? Date(),
                    eventType: eventType,
                    filename: filename,
                    details: details
                )
            }.sorted { $0.timestamp > $1.timestamp } 
        } catch {
            print("Failed to read audit log: \(error)")
            return []
        }
    }
}

enum AuditEventType: String {
    case vaultUnlocked = "VAULT_UNLOCKED"
    case vaultLocked = "VAULT_LOCKED"
    case fileEncrypted = "FILE_ENCRYPTED"
    case fileDecrypted = "FILE_DECRYPTED"
    case fileAccessed = "FILE_ACCESSED"
    case fileDeleted = "FILE_DELETED"
    
    var icon: String {
        switch self {
        case .vaultUnlocked: return "lock.open.fill"
        case .vaultLocked: return "lock.fill"
        case .fileEncrypted: return "shield.fill"
        case .fileDecrypted: return "shield.lefthalf.fill"
        case .fileAccessed: return "eye.fill"
        case .fileDeleted: return "trash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .vaultUnlocked: return .green
        case .vaultLocked: return .blue
        case .fileEncrypted: return .purple
        case .fileDecrypted: return .orange
        case .fileAccessed: return .yellow
        case .fileDeleted: return .red
        }
    }
}

struct AuditEvent: Identifiable {
    var id = UUID()
    let timestamp: Date
    let eventType: AuditEventType
    let filename: String?
    let details: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
