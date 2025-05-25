import Foundation
import SwiftUI

enum Category: String, CaseIterable, Identifiable {
    case all = "All Files"
    case publicFiles = "Public"
    case privateFiles = "Private"
    case sensitive = "Sensitive"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .all: return "folder"
        case .publicFiles: return "folder.fill"
        case .privateFiles: return "folder.fill.badge.person.crop"
        case .sensitive: return "folder.fill.badge.questionmark"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .publicFiles: return .green
        case .privateFiles: return .yellow
        case .sensitive: return .red
        }
    }
}
