# AI Privacy Vault

AI Privacy Vault is an intelligent document and media management system that automatically detects and secures sensitive content using machine learning.

## 📋 Overview

AI Privacy Vault uses CoreML to analyze text and images for sensitive content and automatically categorizes files based on privacy levels. The app provides secure storage with encryption for sensitive materials while maintaining easy access for non-sensitive content.

## 🛠️ Technologies Used

### Frontend
- **Swift & SwiftUI**: Modern, declarative UI framework for all Apple platforms
- **Core ML**: On-device machine learning for content classification
- **Core Data**: Local database for efficient file and metadata management
- **CloudKit**: Secure cloud synchronization across user devices
- **Vision**: Advanced image analysis and text recognition
- **CryptoKit**: Strong encryption for sensitive data protection
- **Local Authentication**: Biometric and password protection
- **Natural Language**: Advanced text analysis capabilities
- **Combine**: Reactive programming for data flow management
- **Swift Concurrency**: Async/await patterns for smooth performance

### Backend
- **Go (Golang)**: Fast, efficient programming language for the server
- **Gin**: Lightweight web framework with excellent performance
- **SQLite**: Embedded SQL database for metadata storage
- **JWT**: JSON Web Tokens for secure authentication
- **bcrypt**: Industry-standard password hashing
- **ZeroConf/mDNS**: Service discovery for local network operation
- **dotenv**: Environment configuration management
- **Concurrency**: Go's goroutines and channels for efficient processing

## ✨ Features

- **Intelligent Content Classification**: Automatically detects sensitive content in text and images
- **Multi-level Privacy Categorization**: Classifies content as Public, Private, or Sensitive
- **Secure Encryption**: End-to-end encryption for sensitive files
- **Smart Search**: Find files while maintaining privacy boundaries
- **Cross-device Sync**: Securely synchronize your vault across Apple devices
- **User-friendly Interface**: Beautiful SwiftUI interface with intuitive controls

## 🖼️ Screenshots

| Home Screen | File Analysis | Vault Browser |
|-------------|---------------|---------------|
| ![Home](https://github.com/user-attachments/assets/a51c1957-0056-49e0-bf23-b0681eec4fa8400x800) | ![Analysis](https://placeholder.com/analysis-screenshot-400x800) | ![Vault](https://placeholder.com/vault-screenshot-400x800) |
<img width="1159" alt="Image" src="https://github.com/user-attachments/assets/a51c1957-0056-49e0-bf23-b0681eec4fa8" />
| Settings | Security Options | AI Classification |
|----------|------------------|-------------------|
| ![Settings](https://placeholder.com/settings-screenshot-400x800) | ![Security](https://placeholder.com/security-screenshot-400x800) | ![AI](https://placeholder.com/ai-screenshot-400x800) |

## 🚀 Getting Started

### System Requirements
- macOS Monterey or later (for development)
- Xcode 14+ 
- iOS 16+ / macOS 13+ (for running the app)

### Installation

2. Open the project in Xcode:
   ```bash
   open "AI Privacy Vault.xcodeproj"
   ```

3. Add required CoreML models (see [Model Integration](#model-integration) section)

4. Build and run the project (⌘+R)

## 🧠 Model Integration

The app requires two CoreML models to function properly:

### 1. Text Classification Model (`SensitiveContentClassifier.mlmodel`)

This model categorizes text as Sensitive, Private, or Public.

- Place in: `/AI Privacy Vault/Models/CoreMLModels/`
- [Instructions for creating this model](ModelCreationGuide.md)

### 2. Image Classification Model (`MobileNetV2.mlmodel` or similar)

This model detects objects in images to determine potential privacy concerns.

- Place in: `/AI Privacy Vault/Models/CoreMLModels/`
- You can use Apple's standard MobileNetV2 model or [create a custom one](ModelCreationGuide.md)

## 🔐 Privacy Focus

AI Privacy Vault emphasizes user privacy by:

1. Performing all AI analysis on-device
2. Never sending sensitive content to remote servers
3. Using strong encryption for sensitive data
4. Providing granular control over privacy settings
