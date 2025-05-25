import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: FileViewModel
    @State private var selectedFile: FileItem?
    @State private var hoveredFile: String? = nil
    
    var body: some View {
        Group {
            if viewModel.isGridView {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 170))], spacing: 20) {
                        ForEach(viewModel.filteredFiles) { file in
                            NavigationLink(destination: FileDetailView(file: file)) {
                                FileGridItemView(file: file)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(Color(.windowBackgroundColor).opacity(0.5))
            } else {
                List(viewModel.filteredFiles, selection: $selectedFile) { file in
                    NavigationLink(destination: FileDetailView(file: file)) {
                        HStack(spacing: 12) {
                            // File icon in nice circle background
                            ZStack {
                                Circle()
                                    .fill(file.category.color.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: getSystemIconForFile(file.name))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(file.category.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.name)
                                    .font(.system(size: 14, weight: .medium))
                                
                                HStack(spacing: 6) {
                                    Text(formatFileSize(file.size))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(file.dateAdded, format: .dateTime.month().day().year())
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Better category tag
                            Text(file.category.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(file.category.color.opacity(0.15))
                                )
                                .foregroundColor(file.category.color)
                            
                            // Risk indicator
                            HStack(spacing: 4) {
                                Image(systemName: file.riskLevel.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if hoveredFile == file.id.uuidString {
                                    Text(file.riskLevel.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, hoveredFile == file.id.uuidString ? 10 : 6)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(file.riskLevel.color)
                            )
                            .animation(.easeInOut(duration: 0.2), value: hoveredFile)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation {
                                self.hoveredFile = hovering ? file.id.uuidString : nil
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(viewModel.selectedCategory.rawValue)
        .overlay(
            Group {
                if viewModel.isAnalyzing {
                    ZStack {
                        Color(.windowBackgroundColor).opacity(0.9)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding(.bottom, 8)
                            
                            Text("Analyzing files...")
                                .font(.headline)
                            
                            Text("Using AI to detect sensitive content")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Material.ultraThin)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
                    }
                    .transition(.opacity)
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        viewModel.isGridView.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
