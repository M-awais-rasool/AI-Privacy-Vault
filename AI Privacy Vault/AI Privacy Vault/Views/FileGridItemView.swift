import SwiftUI

struct FileGridItemView: View {
    let file: FileItem
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.windowBackgroundColor),
                                Color(.windowBackgroundColor).opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: isHovering ? 6 : 3, x: 0, y: 2)
                    .frame(width: 130, height: 100)
                    .overlay(
                        ZStack {
                            // Background accent color glow
                            Circle()
                                .fill(file.category.color.opacity(0.15))
                                .frame(width: 60, height: 60)
                                .blur(radius: 10)
                            
                            // File icon
                            Image(systemName: getSystemIconForFile(file.name))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 42, height: 42)
                                .foregroundColor(file.category.color)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(file.category.color.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: file.riskLevel.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(file.riskLevel.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .shadow(color: file.riskLevel.color.opacity(0.6), radius: 3, x: 0, y: 1)
                    .padding(6)
            }
            
            VStack(spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 120, alignment: .center)
                
                Text(formatFileSize(file.size))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func getSystemIconForFile(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png": return "photo.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "chart.bar.doc.horizontal.fill"
        case "txt": return "doc.plaintext.fill"
        default: return "doc.fill"
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
