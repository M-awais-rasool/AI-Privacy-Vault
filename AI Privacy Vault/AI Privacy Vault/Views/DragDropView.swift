import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DragDropView: View {
    @ObservedObject var viewModel: FileViewModel
    @EnvironmentObject var vaultViewModel: VaultViewModel
    @State private var isDropTargeted = false
    @State private var animating = false
    
    var body: some View {
        ZStack {
            // Background with animated gradient when targeted
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isDropTargeted ? 
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.15),
                            Color.accentColor.opacity(0.25)
                        ]),
                        startPoint: animating ? .topLeading : .bottomTrailing,
                        endPoint: animating ? .bottomTrailing : .topLeading
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.windowBackgroundColor).opacity(0.5),
                            Color(.windowBackgroundColor)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(
                                lineWidth: 2,
                                dash: [6],
                                dashPhase: animating ? 10 : 0
                            )
                        )
                        .foregroundColor(isDropTargeted ? .accentColor : .secondary.opacity(0.6))
                )
                .shadow(
                    color: isDropTargeted ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isDropTargeted ? 10 : 4,
                    x: 0,
                    y: isDropTargeted ? 4 : 2
                )
            
            VStack(spacing: 12) {
                ZStack {
                    // Animated circle background for icon
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: isDropTargeted ? 60 : 50, height: isDropTargeted ? 60 : 50)
                        .scaleEffect(animating && isDropTargeted ? 1.1 : 1.0)
                    
                    // Document icon
                    Image(systemName: "arrow.down.doc")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                        .offset(y: animating && isDropTargeted ? -2 : 2)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animating)
                }
                
                VStack(spacing: 4) {
                    Text("Drag & Drop Your Files")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Files will be secured in your vault")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .opacity(isDropTargeted ? 1.0 : 0.8)
            .scaleEffect(isDropTargeted ? 1.05 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDropTargeted)
        .onDrop(of: [UTType.item.identifier], isTargeted: $isDropTargeted) { providers in
            // Process drop...same logic as original
            for provider in providers {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, error in
                    guard let originalURL = url, error == nil else {
                        print("Error loading dropped file: \(error?.localizedDescription ?? "Unknown error")")
                        DispatchQueue.main.async {
                            viewModel.errorMessage = "Error loading dropped file"
                        }
                        return
                    }
                    
                    do {
                        // Immediately copy the file to our app's temporary directory
                        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                            UUID().uuidString + "-" + originalURL.lastPathComponent
                        )
                        
                        // Copy the file data
                        let fileData = try Data(contentsOf: originalURL)
                        try fileData.write(to: temporaryURL)
                        
                        DispatchQueue.main.async {
                            // Add file to both the FileViewModel and the VaultViewModel
                            viewModel.addFile(url: temporaryURL, category: viewModel.selectedCategory)
                            
                            // This is the key addition - ensure the file is properly stored in the vault
                            vaultViewModel.addFileToVault(url: temporaryURL)
                        }
                    } catch {
                        print("Failed to copy dropped file: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            viewModel.errorMessage = "Failed to process file: \(error.localizedDescription)"
                        }
                    }
                }
            }
            
            return true
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animating = true
            }
        }
    }
}
