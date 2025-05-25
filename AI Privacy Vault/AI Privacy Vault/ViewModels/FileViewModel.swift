import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

class FileViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var selectedCategory: Category = .all
    @Published var searchText: String = ""
    @Published var isGridView: Bool = false
    @Published var isAnalyzing: Bool = false
    @Published var errorMessage: String? = nil
    
    private var vaultViewModel: VaultViewModel?
    
    private let fileAnalyzer = FileAnalyzerService()
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let sampleFiles = [
            FileItem(name: "Business Plan.pdf", url: URL(string: "file://sample")!, category: .publicFiles, dateAdded: Date(), size: 1024 * 1024 * 3, riskLevel: .safe),
            FileItem(name: "Personal Photos.jpg", url: URL(string: "file://sample")!, category: .privateFiles, dateAdded: Date(), size: 1024 * 1024 * 8, riskLevel: .moderate),
            FileItem(name: "Financial Records.xlsx", url: URL(string: "file://sample")!, category: .sensitive, dateAdded: Date(), size: 1024 * 1024 * 2, riskLevel: .high),
            FileItem(name: "Project Notes.txt", url: URL(string: "file://sample")!, category: .publicFiles, dateAdded: Date(), size: 1024 * 512, riskLevel: .safe)
        ]
        
        files = sampleFiles
    }
    
    var filteredFiles: [FileItem] {
        files.filter { file in
            let categoryMatch = selectedCategory == .all || file.category == selectedCategory
            let searchMatch = searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && searchMatch
        }
    }
    
    func syncWithVaultViewModel(_ vault: VaultViewModel) {
        self.vaultViewModel = vault
        
        loadFilesFromVault()
        
        vaultViewModel?.$vaultFiles
            .sink { [weak self] vaultFiles in
                self?.loadFilesFromVault()
            }
            .store(in: &cancellables)
    }
    
    private func loadFilesFromVault() {
        guard let vaultViewModel = vaultViewModel, !vaultViewModel.isVaultLocked else { return }
        
        self.files = []
        
        for vaultFile in vaultViewModel.vaultFiles {
            let fileItem = FileItem(
                name: vaultFile.originalName,
                url: vaultFile.encryptedURL,  
                category: .privateFiles,     
                dateAdded: vaultFile.dateAdded,
                size: vaultFile.size,
                riskLevel: .moderate,         
                riskScore: 50,                
                detectedKeywords: []          
            )
            
            self.files.append(fileItem)
        }
    }
    
    func addFile(url: URL, category: Category? = nil) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            isAnalyzing = true
            print("Starting analysis of: \(url.lastPathComponent)")
            
            Task {
                do {
                    let assessment = await fileAnalyzer.analyzeFile(at: url)
                    
                    var processedKeywords = [String]()
                    var seen = Set<String>()
                    
                    for keyword in assessment.detectedKeywords {
                        if keyword.count > 50 {
                            continue
                        }
                        
                        let lowerKeyword = keyword.lowercased()
                        if !seen.contains(lowerKeyword) {
                            seen.insert(lowerKeyword)
                            processedKeywords.append(keyword)
                        }
                    }
                    
                    print("Analysis complete - Risk score: \(assessment.riskScore), Keywords: \(processedKeywords.count)")
                    
                    let fileCategory = category ?? assessment.suggestedCategory
                    
                    let newFile = FileItem(
                        name: url.lastPathComponent,
                        url: url, 
                        category: fileCategory,
                        dateAdded: Date(),
                        size: fileSize,
                        riskLevel: assessment.riskLevel,
                        riskScore: assessment.riskScore,
                        detectedKeywords: processedKeywords
                    )
                    
                    await MainActor.run {
                        self.files.append(newFile)
                        self.isAnalyzing = false
                    }
                } catch {
                    print("Error processing file: \(error)")
                    await MainActor.run {
                        self.isAnalyzing = false
                        self.errorMessage = "Failed to process file: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            self.errorMessage = "Failed to get file attributes: \(error.localizedDescription)"
            print("Error getting file attributes: \(error)")
        }
    }
    
    func addFileWithBookmark(url: URL, bookmarkData: Data, category: Category? = nil) {
        addFile(url: url, category: category)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
