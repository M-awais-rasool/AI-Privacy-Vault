# Model Creation Guide for AI Privacy Vault

This guide provides detailed instructions for creating, customizing, and integrating the machine learning models required by AI Privacy Vault.

## Text Classification Model

AI Privacy Vault requires a text classifier that can identify sensitive content. Here's how to build one:

### Option 1: Create a Custom Text Classifier from Scratch

1. **Prepare Your Training Data**
   - Create a folder structure on your desktop:
   ```
   SensitiveContentData/
   ├── sensitive/
   │   ├── sensitive1.txt
   │   ├── sensitive2.txt
   │   └── ... (at least 20 files recommended)
   ├── private/
   │   ├── private1.txt
   │   └── ... (at least 20 files recommended)
   └── public/
       ├── public1.txt
       └── ... (at least 20 files recommended)
   ```

2. **Add Example Content to Each Category**
   
   **Sensitive Examples:**
   - Credit card numbers, SSNs, passwords
   - Medical records
   - Financial statements
   - Legal documents with personal identifiers
   
   **Private Examples:**
   - Personal addresses, phone numbers
   - Non-sensitive personal communications
   - Workplace information
   - Travel plans
   
   **Public Examples:**
   - General news content
   - Public information
   - Non-personal notes or documents
   - General reference material

3. **Create the Model in Create ML**
   - Open the Create ML app
   - Choose "Text Classification" project type
   - Drag your `SensitiveContentData` folder to the Data section
   - Configure:
     - Algorithm: Maximum Entropy (for smaller datasets) or Neural Network (for larger datasets)
     - Word Embedding: Dynamic
     - Validation: Automatic (20%)
   - Click "Train"
   - Review evaluation metrics (aim for >90% accuracy)
   - Test with sample inputs
   - Export as `SensitiveContentClassifier.mlmodel`

## Image Classification Model

### Option 1: Use MobileNetV2 (Recommended for Most Users)

MobileNetV2 is a pre-trained model that can identify 1000 different objects, many of which have privacy implications.

1. Download the model:
   - From [Apple's ML Model Gallery](https://developer.apple.com/machine-learning/models/)
   - Or from [this direct link](https://ml-assets.apple.com/coreml/models/MobileNetV2.mlmodel)

2. The AI Privacy Vault app is pre-configured to work with MobileNetV2's categories, mapping them to privacy sensitivity levels.

### Option 2: Create a Custom Image Classifier

For specialized use cases, you can create a custom image classifier:

1. **Gather Training Images**
   - Collect at least 100 images per category:
     - `sensitive/`: Documents, credit cards, IDs, etc.
     - `private/`: Personal photos, home interiors, etc.
     - `public/`: Landscapes, objects, etc.

2. **Use Create ML to Build the Model**
   - Open Create ML
   - Select "Image Classification" project type
   - Drag your categorized images folder
   - Train the model (use augmentation for better results)
   - Export as `ImageClassifier.mlmodel`

## Integrating Models into AI Privacy Vault

1. **Add models to your Xcode project:**
   - In Xcode, right-click on the `AI Privacy Vault/Models/CoreMLModels` folder
   - Select "Add Files to AI Privacy Vault..."
   - Navigate to your model files
   - Ensure "Copy items if needed" is checked
   - Select your app target
   - Click "Add"

2. **Verify model integration:**
   - Build and run the app
   - Navigate to Settings > AI Models
   - You should see the status "Loaded" for both models
   - Try the "Test Models" feature to verify functionality

## Advanced Model Customization

For advanced users who want to further customize model behavior:

### Fine-tuning Text Classification

You can modify the sensitivity thresholds in the code:

1. Open `ModelManager.swift`
2. Locate the `classifyText` function
3. Adjust the confidence thresholds to make the model more or less sensitive

### Enhancing Image Classification

To improve image classification accuracy for specific use cases:

1. Create additional training data focused on your specific needs
2. Use Create ML's "Fine Tuning" option with MobileNetV2 as the base
3. This allows you to add your own categories while leveraging the power of the pre-trained model

## Troubleshooting Model Issues

If you encounter problems with your models:

- **Model not found**: Ensure models are added to the "Copy Bundle Resources" build phase
- **Poor classification results**: Add more diverse training examples
- **Slow performance**: Consider using a quantized version of MobileNetV2 for faster inference
- **Model compilation errors**: Ensure you're using models compatible with your deployment target iOS version
