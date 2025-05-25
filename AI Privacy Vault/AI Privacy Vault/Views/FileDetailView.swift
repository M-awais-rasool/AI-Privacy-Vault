import SwiftUI

struct FileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var animateContent = false
    
    let file: FileItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // File header with glassmorphism effect
                ZStack(alignment: .bottomLeading) {
                    // Background gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    file.category.color.opacity(0.3),
                                    file.category.color.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)
                    
                    // Header content with file info
                    HStack(spacing: 20) {
                        // File icon with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            file.category.color.opacity(0.8),
                                            file.category.color.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 84, height: 84)
                                .shadow(color: file.category.color.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: getSystemIconForFile(file.name))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(file.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 12) {
                                Label(formatFileSize(file.size), systemImage: "doc.circle")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                                
                                Label(formattedDate(file.dateAdded), systemImage: "calendar")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)
                        }
                        .offset(y: animateContent ? 0 : 20)
                        .opacity(animateContent ? 1 : 0)
                    }
                    .padding(24)
                }
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                
                // Risk assessment card
                VStack(alignment: .leading, spacing: 16) {
                    Label("Risk Assessment", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .foregroundColor(file.riskLevel.color)
                    
                    // Risk score with animated bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Risk Score:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(file.riskScore)%")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(file.riskLevel.color)
                        }
                        
                        // Animated progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 14)
                                
                                // Filled portion
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                file.riskLevel.color.opacity(0.8),
                                                file.riskLevel.color
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: animateContent ? geometry.size.width * CGFloat(file.riskScore) / 100 : 0, height: 14)
                                    .animation(.easeOut(duration: 1.0).delay(0.3), value: animateContent)
                            }
                        }
                        .frame(height: 14)
                    }
                    .padding(.bottom, 8)
                    
                    // Risk indicators
                    HStack(spacing: 20) {
                        // Risk level indicator
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Risk Level")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: file.riskLevel.icon)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(file.riskLevel.color)
                                    .clipShape(Circle())
                                
                                Text(file.riskLevel.rawValue)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(file.riskLevel.color)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Category indicator
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Category")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(file.category.rawValue)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(file.category.color.opacity(0.15))
                                )
                                .foregroundColor(file.category.color)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                
                // Keywords card
                if !file.detectedKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Detected Sensitive Content", systemImage: "eye.slash")
                            .font(.headline)
                        
                        ForEach(groupKeywords(file.detectedKeywords), id: \.group) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                if !item.group.isEmpty {
                                    Text(item.group)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(item.keywords, id: \.self) { keyword in
                                        KeywordBubbleView(keyword: keyword)
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                }
                
                Spacer(minLength: 30)
            }
            .padding(.vertical, 20)
        }
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .navigationTitle("File Details")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct RiskScoreView: View {
    let score: Int
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .frame(width: 200, height: 20)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            Rectangle()
                .frame(width: CGFloat(score) / 100 * 200, height: 20)
                .foregroundColor(scoreColor)
            
            Text("\(score)%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 8)
        }
        .cornerRadius(10)
    }
    
    var scoreColor: Color {
        if score < 30 {
            return .green
        } else if score < 70 {
            return .yellow
        } else {
            return .red
        }
    }
}

// Keyword bubble component
struct KeywordBubbleView: View {
    let keyword: String
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Icon based on keyword type
            Group {
                if keyword.hasPrefix("📷") {
                    Image(systemName: "photo")
                } else if keyword.hasPrefix("📝") {
                    Image(systemName: "doc.text")
                } else if keyword.hasPrefix("ML:") {
                    Image(systemName: "brain")
                } else if keyword.hasPrefix("-") {
                    Image(systemName: "minus")
                } else {
                    Image(systemName: "exclamationmark.triangle")
                }
            }
            .font(.system(size: 12))
            
            Text(formatKeyword(keyword))
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(getKeywordColor(keyword).opacity(isHovering ? 0.25 : 0.15))
        )
        .foregroundColor(getKeywordColor(keyword))
        .overlay(
            Capsule()
                .stroke(getKeywordColor(keyword).opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func formatKeyword(_ keyword: String) -> String {
        // Remove prefixes for display
        if keyword.hasPrefix("📷 ") {
            return keyword.replacingOccurrences(of: "📷 ", with: "")
        }
        if keyword.hasPrefix("📝 ") {
            return keyword.replacingOccurrences(of: "📝 ", with: "")
        }
        // Limit length for better display
        let processed = keyword
        if processed.count > 30 {
            return String(processed.prefix(27)) + "..."
        }
        return processed
    }
    
    private func getKeywordColor(_ keyword: String) -> Color {
        // Colors based on keyword type
        if keyword.contains("Credit Card") || 
           keyword.contains("SSN") || 
           keyword.contains("passport") ||
           keyword.contains("identification") {
            return .red
        } else if keyword.contains("address") || 
                  keyword.contains("phone") || 
                  keyword.contains("email") {
            return .orange
        } else if keyword.hasPrefix("📷") {
            return .blue
        } else if keyword.hasPrefix("📝") {
            return .purple
        } else if keyword.contains("ML:") {
            return .green
        } else {
            return .gray
        }
    }
}

// Helper view for flowing layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
        
        height = y + maxHeight
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
    }
}

// Add these helper methods at the end of the struct
extension FileDetailView {
    private func groupKeywords(_ keywords: [String]) -> [(group: String, keywords: [String])] {
        var groups: [String: [String]] = [
            "Image Content": [],
            "Text Content": [],
            "Machine Learning": [],
            "Details": [],
            "Other": []
        ]
        
        for keyword in keywords {
            if keyword.hasPrefix("📷") {
                groups["Image Content"]?.append(keyword)
            } else if keyword.hasPrefix("📝") {
                groups["Text Content"]?.append(keyword.replacingOccurrences(of: "📝 ", with: ""))
            } else if keyword.hasPrefix("ML:") {
                groups["Machine Learning"]?.append(keyword)
            } else if keyword.hasPrefix("-") {
                groups["Details"]?.append(keyword)
            } else {
                groups["Other"]?.append(keyword)
            }
        }
        
        // Convert to array and remove empty groups
        return groups.compactMap { key, value in
            if value.isEmpty {
                return nil
            }
            return (group: key, keywords: value)
        }.sorted { $0.group < $1.group }
    }
}
