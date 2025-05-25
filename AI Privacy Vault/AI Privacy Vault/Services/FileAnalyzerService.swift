import Foundation
import Vision
import CoreML
import NaturalLanguage
import AppKit
import PDFKit
import RegexBuilder

class FileAnalyzerService {
    
    private let modelManager = ModelManager.shared
    
    private let sensitiveKeywordsDict: [String: [String]] = [
        "Financial": [
            "account number", "credit card", "debit card", "expiration date", "cvv", "banking", 
            "financial", "tax", "salary", "income", "loan", "mortgage", "investment", "balance",
            "routing number", "bank account", "transaction", "statement", "invoice", "payment"
        ],
        "Personal Identity": [
            "social security", "ssn", "passport", "license", "id card", "identification", 
            "birth date", "birthdate", "date of birth", "address", "home address", "zip code",
            "postal code", "driver license", "national id", "citizenship", "biometric"
        ],
        "Contact": [
            "phone number", "email", "address", "contact", "emergency contact", "fax",
            "mobile", "cell phone", "telephone", "email address", "home phone"
        ],
        "Medical": [
            "medical", "health", "insurance", "diagnosis", "prescription", "medication",
            "patient", "doctor", "hospital", "treatment", "condition", "illness", "symptom",
            "blood type", "allergy", "medical record", "health record", "vaccine", "vaccination"
        ],
        "Security": [
            "password", "secret", "confidential", "private", "personal", "restricted",
            "authentication", "security question", "pin", "access code", "login"
        ]
    ]
    
    private let sensitiveDataPatterns: [(name: String, pattern: String, riskScore: Int)] = [
        ("Credit Card", #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\d{3})\d{11})\b"#, 95),
        ("SSN", #"\b(?:\d{3}-\d{2}-\d{4}|\d{9})\b"#, 95),
        ("Email Address", #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#, 70),
        ("Phone Number", #"\b(?:\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b"#, 70),
        ("Date of Birth", #"\b(?:0[1-9]|1[0-2])[/.-](?:0[1-9]|[12][0-9]|3[01])[/.-](?:19|20)\d\d\b"#, 85),
        ("IP Address", #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#, 50),
        ("URL", #"\bhttps?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)"#, 40)
    ]
    
    private lazy var sensitiveKeywords: [String] = {
        var allKeywords: [String] = []
        for (_, words) in sensitiveKeywordsDict {
            allKeywords.append(contentsOf: words)
        }
        return allKeywords
    }()
    
    func analyzeFile(at url: URL) async -> FileRiskAssessment {
        print("Starting analysis of file: \(url.lastPathComponent)")
        let fileType = determineFileType(url)
        print("Detected file type: \(fileType)")
        
        switch fileType {
        case .text, .pdf:
            return await analyzeTextFile(at: url, fileType: fileType)
        case .image:
            return await analyzeImageFile(at: url)
        default:
            print("Unknown file type. Using default moderate risk assessment.")
            return FileRiskAssessment(
                riskScore: 50,
                suggestedCategory: .privateFiles,
                riskLevel: .moderate,
                detectedKeywords: []
            )
        }
    }
    
    private func determineFileType(_ url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "txt", "doc", "docx", "rtf", "md":
            return .text
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "tiff":
            return .image
        case "mp4", "mov", "avi", "m4v":
            return .video
        default:
            return .other
        }
    }
    
    private func analyzeTextFile(at url: URL, fileType: FileType) async -> FileRiskAssessment {
        var text = ""
        
        if fileType == .pdf {
            if let pdfDocument = PDFDocument(url: url) {
                for i in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: i), let pageText = page.string {
                        text += pageText + " "
                    }
                }
                print("Extracted \(text.count) characters from PDF")
            } else {
                print("Failed to load PDF document")
            }
        } else {
            do {
                text = try String(contentsOf: url, encoding: .utf8)
                print("Loaded text file with \(text.count) characters")
            } catch {
                print("Error reading file: \(error)")
                for encoding in [String.Encoding.ascii, .isoLatin1, .windowsCP1252] {
                    do {
                        text = try String(contentsOf: url, encoding: encoding)
                        print("Successfully loaded with alternative encoding")
                        break
                    } catch {
                    }
                }
            }
        }
        
        return await analyzeText(text)
    }
    
    private func analyzeImageFile(at url: URL) async -> FileRiskAssessment {
        print("Starting image analysis for: \(url.lastPathComponent)")
        var assessment = FileRiskAssessment(
            riskScore: 30,
            suggestedCategory: .publicFiles,
            riskLevel: .safe,
            detectedKeywords: []
        )
        
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to load image or convert to CGImage")
            return assessment
        }
        
        print("Image loaded successfully, dimensions: \(image.size.width) x \(image.size.height)")
        
        if let classificationResults = await modelManager.classifyImage(cgImage) {
            print("Image classification results: \(classificationResults)")
            
            var highestRiskScore = 0
            var detectedSensitiveClasses: [String] = []
            
            for result in classificationResults {
                let riskScore = calculateImageRiskScore(label: result.label, confidence: result.confidence)
                highestRiskScore = max(highestRiskScore, riskScore)
                
                if riskScore > 30 && result.confidence > 0.5 {
                    let percentConfidence = Int(result.confidence * 100)
                    detectedSensitiveClasses.append("📷 \(result.label) (\(percentConfidence)%)")
                }
            }
            
            assessment.riskScore = highestRiskScore
            assessment.detectedKeywords = detectedSensitiveClasses
            
            print("Image classification risk score: \(highestRiskScore)")
            print("Detected sensitive classes: \(detectedSensitiveClasses)")
            
            (assessment.riskLevel, assessment.suggestedCategory) = 
                determineRiskLevelAndCategory(score: highestRiskScore)
        } else {
            print("No image classification results available")
        }
        
        if let extractedText = await performOCR(cgImage) {
            print("OCR extracted text length: \(extractedText.count) characters")
            
            let textAssessment = await analyzeText(extractedText)
            print("Text assessment from OCR: score=\(textAssessment.riskScore), keywords count=\(textAssessment.detectedKeywords.count)")
            
            let ocrKeywords = textAssessment.detectedKeywords.map { "📝 \($0)" }
            
            assessment.detectedKeywords.append(contentsOf: ocrKeywords)
            
            if textAssessment.riskScore > assessment.riskScore {
                assessment.riskScore = textAssessment.riskScore
                assessment.riskLevel = textAssessment.riskLevel
                assessment.suggestedCategory = textAssessment.suggestedCategory
                print("Using OCR text analysis risk score: \(assessment.riskScore)")
            }
        } else {
            print("OCR extraction failed or returned no text")
        }
        
        print("Final assessment for image: score=\(assessment.riskScore), level=\(assessment.riskLevel)")
        
        return assessment
    }
    
    private func calculateImageRiskScore(label: String, confidence: Float) -> Int {
        let highRiskLabels = [
            "passport", "id card", "credit card", "document", "nude", "personal", "medical", 
            "license", "certificate", "receipt", "bill", "statement", "identification"
        ]
        
        let mediumRiskLabels = [
            "person", "people", "face", "home", "house", "office", "photo", "portrait",
            "group", "meeting", "gathering", "letter", "mail", "screen", "display"
        ]
        
        let lowercasedLabel = label.lowercased()
        
        for riskLabel in highRiskLabels {
            if lowercasedLabel.contains(riskLabel) {
                return Int(min(confidence * 100 + 40, 100))
            }
        }
        
        for riskLabel in mediumRiskLabels {
            if lowercasedLabel.contains(riskLabel) {
                return Int(min(confidence * 70 + 20, 85))
            }
        }
        
        return Int(min(confidence * 40, 40))
    }
    
    private func performOCR(_ image: CGImage) async -> String? {
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["en-US"] 
        
        do {
            try requestHandler.perform([request])
            guard let observations = request.results, !observations.isEmpty else { 
                print("No OCR results")
                return nil 
            }
            
            var recognizedText = ""
            var previousBounds: CGRect?
            
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    let bounds = observation.boundingBox
                    if let prevBounds = previousBounds {
                        if abs(bounds.minY - prevBounds.minY) > 0.02 {
                            recognizedText += "\n"
                        } else if recognizedText.last != " " && !recognizedText.isEmpty {
                            recognizedText += " "
                        }
                    }
                    
                    recognizedText += candidate.string
                    previousBounds = observation.boundingBox
                }
            }
            
            print("OCR recognized \(observations.count) text regions")
            return recognizedText
        } catch {
            print("Failed to perform OCR: \(error)")
            return nil
        }
    }
    
    private func analyzeText(_ text: String) async -> FileRiskAssessment {
        if text.isEmpty {
            print("Empty text provided for analysis")
            return FileRiskAssessment(
                riskScore: 0,
                suggestedCategory: .publicFiles,
                riskLevel: .safe,
                detectedKeywords: []
            )
        }
        
        var detectedKeywords = [String]()
        var riskScore = 0
        var categoryScores: [String: Int] = [:]
        
        if let (label, confidence) = modelManager.analyzeSensitiveText(text) {
            print("ML text analysis result: \(label) with confidence \(confidence)")
            
            if label == "sensitive" || label == "private" || label == "confidential" {
                riskScore = Int(confidence * 100)
            } else {
                riskScore = 100 - Int(confidence * 100) 
            }
            
            let confidencePercent = Int(confidence * 100)
            detectedKeywords.append("ML: \(label) (\(confidencePercent)%)")
        } else {
            print("Falling back to keyword-based analysis")
            
            for patternInfo in sensitiveDataPatterns {
                do {
                    let regex = try NSRegularExpression(pattern: patternInfo.pattern, options: [])
                    let nsString = text as NSString
                    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    if !matches.isEmpty {
                        riskScore = max(riskScore, patternInfo.riskScore)
                        detectedKeywords.append("\(patternInfo.name): \(matches.count) instance(s)")
                    }
                } catch {
                    print("Regex error for \(patternInfo.name): \(error)")
                }
            }
            
            let lowercasedText = text.lowercased()
            
            for (category, keywords) in sensitiveKeywordsDict {
                var categoryHits = 0
                var foundKeywords: [String] = []
                
                for keyword in keywords {
                    if lowercasedText.contains(keyword) {
                        categoryHits += 1
                        foundKeywords.append(keyword)
                    }
                }
                
                if !foundKeywords.isEmpty {
                    if foundKeywords.count == 1 {
                        detectedKeywords.append("\(category): \(foundKeywords[0])")
                    } else {
                        detectedKeywords.append("\(category): \(foundKeywords.count) keywords")
                        if foundKeywords.count <= 4 {
                            for keyword in foundKeywords {
                                detectedKeywords.append("- \(keyword)")
                            }
                        }
                    }
                    
                    let categoryScore: Int
                    switch categoryHits {
                    case 1: categoryScore = 40  
                    case 2: categoryScore = 65  
                    case 3...: categoryScore = 85 
                    default: categoryScore = 0
                    }
                    
                    categoryScores[category] = categoryScore
                    riskScore = max(riskScore, categoryScore)
                }
            }
            
            if categoryScores.count > 1 {
                riskScore += min(categoryScores.count * 5, 15) 
            }
        }
        
        print("Text analysis result: score=\(riskScore), detected keywords count=\(detectedKeywords.count)")
        
        let (riskLevel, suggestedCategory) = determineRiskLevelAndCategory(score: riskScore)
        
        return FileRiskAssessment(
            riskScore: riskScore,
            suggestedCategory: suggestedCategory,
            riskLevel: riskLevel,
            detectedKeywords: detectedKeywords
        )
    }
    
    private func determineRiskLevelAndCategory(score: Int) -> (RiskLevel, Category) {
        let riskLevel: RiskLevel
        let suggestedCategory: Category
        
        switch score {
        case 0..<30:
            riskLevel = .safe
            suggestedCategory = .publicFiles
        case 30..<70:
            riskLevel = .moderate
            suggestedCategory = .privateFiles
        default:
            riskLevel = .high
            suggestedCategory = .sensitive
        }
        
        return (riskLevel, suggestedCategory)
    }
}

enum FileType {
    case text
    case pdf
    case image
    case video
    case other
}

struct FileRiskAssessment {
    var riskScore: Int 
    var suggestedCategory: Category
    var riskLevel: RiskLevel
    var detectedKeywords: [String]
}
