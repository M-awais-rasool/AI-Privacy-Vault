import Foundation
import CoreML
import Vision
import NaturalLanguage
import AppKit

class ModelManager {
    static let shared = ModelManager()
    
    private var imageClassificationModel: VNCoreMLModel?
    
    private var textClassificationModel: NLModel?
    
    var isImageModelAvailable: Bool { imageClassificationModel != nil }
    var isTextModelAvailable: Bool { textClassificationModel != nil }
    
    private init() {
        loadModels()
    }
    
    private func loadModels() {
        loadImageClassificationModel()
        
        loadTextClassificationModel()
    }
    
    private func loadImageClassificationModel() {
        do {
            if let modelURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc") {
                imageClassificationModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
                print("Successfully loaded image classification model")
            } else {
                print("Image classification model not found in bundle")
            }
        } catch {
            print("Failed to load image classification model: \(error)")
        }
    }
    
    private func loadTextClassificationModel() {
        do {
            if let modelURL = Bundle.main.url(forResource: "MyTextClassifier", withExtension: "mlmodelc") {
                textClassificationModel = try NLModel(contentsOf: modelURL)
                print("Successfully loaded text classification model")
            } else {
                print("Text classification model not found in bundle")
            }
        } catch {
            print("Failed to load text classification model: \(error)")
        }
    }
    
    
    func classifyImage(_ image: CGImage) async -> [(label: String, confidence: Float)]? {
        guard let model = imageClassificationModel else {
            print("Image classification model not available")
            return nil
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("Vision request error: \(error)")
                return
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results as? [VNClassificationObservation] else {
                print("No valid results from image classification request")
                return nil
            }
            
            return Array(results.prefix(10)).map { (label: $0.identifier, confidence: $0.confidence) }
        } catch {
            print("Failed to perform classification: \(error)")
            return nil
        }
    }
    
    func analyzeSensitiveText(_ text: String) -> (label: String, confidence: Double)? {
        guard let model = textClassificationModel else {
            print("Text classification model not available")
            return nil
        }
        
        if let predictedLabel = model.predictedLabel(for: text) {
            let confidence = model.predictedLabelHypotheses(for: text, maximumCount: 1)[predictedLabel] ?? 0.0
            return (predictedLabel, confidence)
        }
        
        return nil
    }
    
    func fallbackTextAnalysis(text: String, sensitiveKeywords: [String]) -> Int {
        let lowercasedText = text.lowercased()
        var keywordCount = 0
        var weightedScore = 0
        
        for keyword in sensitiveKeywords {
            if lowercasedText.contains(keyword) {
                keywordCount += 1
                
                if ["social security", "ssn", "password", "credit card", "passport"].contains(keyword) {
                    weightedScore += 25 
                } else if ["address", "phone", "email", "medical", "financial"].contains(keyword) {
                    weightedScore += 15 
                } else {
                    weightedScore += 10 
                }
            }
        }
        
        let baseScore = min(keywordCount * 10, 50) 
        let totalScore = min(baseScore + weightedScore, 100)
        
        return totalScore
    }
}
