import Foundation
import SwiftUI

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let category: Category
    let dateAdded: Date
    let size: Int64
    let riskLevel: RiskLevel
    let riskScore: Int
    let detectedKeywords: [String]
    
    init(name: String, url: URL, category: Category, dateAdded: Date, size: Int64, riskLevel: RiskLevel, 
         riskScore: Int = 0, detectedKeywords: [String] = []) {
        self.name = name
        self.url = url
        self.category = category
        self.dateAdded = dateAdded
        self.size = size
        self.riskLevel = riskLevel
        self.riskScore = riskScore
        self.detectedKeywords = detectedKeywords
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum RiskLevel: String, CaseIterable {
    case safe = "Safe"
    case moderate = "Moderate"
    case high = "High"
    
    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .moderate: return "exclamationmark.shield.fill"
        case .high: return "xmark.shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .moderate: return .yellow
        case .high: return .red
        }
    }
}
