#!/bin/bash

# Script to download Parakeet model files for bundling with the app

MODEL_DIR="Sources/Resources"
REPO_URL="https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml/resolve/main"

# Create models directory
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "📥 Downloading Parakeet models for bundling..."

# Download the required model files based on AsrModels.ModelNames
download_model_dir() {
    local model_name=$1
    echo "Downloading $model_name..."
    
    # Create directory structure
    mkdir -p "$model_name/weights"
    cd "$model_name"
    
    # Download essential files for CoreML model
    echo "  Downloading coremldata.bin..."
    curl -L -o "coremldata.bin" "$REPO_URL/$model_name/coremldata.bin"
    
    echo "  Downloading metadata.json..."
    curl -L -o "metadata.json" "$REPO_URL/$model_name/metadata.json" 
    
    echo "  Downloading model.mil..."
    curl -L -o "model.mil" "$REPO_URL/$model_name/model.mil"
    
    echo "  Downloading weights/weight.bin..."
    curl -L -o "weights/weight.bin" "$REPO_URL/$model_name/weights/weight.bin"
    
    # Verify all files were downloaded
    if [ -f "coremldata.bin" ] && [ -f "metadata.json" ] && [ -f "model.mil" ] && [ -f "weights/weight.bin" ]; then
        echo "✅ Downloaded $model_name successfully"
    else
        echo "❌ Some files missing for $model_name"
        ls -la
        ls -la weights/ 2>/dev/null || echo "weights directory missing"
    fi
    
    cd ..
}

# Download vocabulary file
echo "Downloading vocabulary file..."
curl -L -o "parakeet_vocab.json" "$REPO_URL/parakeet_vocab.json"

# Download model directories
download_model_dir "Melspectogram.mlmodelc"
download_model_dir "ParakeetEncoder_v2.mlmodelc"  
download_model_dir "ParakeetDecoder.mlmodelc"
download_model_dir "RNNTJoint.mlmodelc"

echo "🎉 All models downloaded to $MODEL_DIR"

# Create checksum for all downloaded files
echo "📋 Creating checksum for all model files..."
CHECKSUM_FILE="models.sha256"
find . -type f \( -name "*.bin" -o -name "*.json" -o -name "*.mil" \) -exec sha256sum {} \; | sort > "$CHECKSUM_FILE"
echo "✅ Checksum saved to $CHECKSUM_FILE"

echo "Now add these files to your Xcode project as bundle resources"
