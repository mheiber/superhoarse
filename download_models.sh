#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script to download Parakeet model files for bundling with the app

MODEL_DIR="Sources/Resources"
TEMP_DIR="${MODEL_DIR}.tmp"
REPO_URL="https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/resolve/main"
VERSION_FILE=".models_version"
LOCK_FILE="/tmp/superhoarse_models.lock"

# Detect OS and set hash command
if command -v sha256sum >/dev/null 2>&1; then
    HASH_CMD="sha256sum"
else
    HASH_CMD="shasum -a 256"
fi

# Acquire exclusive lock to prevent concurrent downloads
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "⏳ Another download in progress, waiting..."; flock 200; }

# Cleanup function for partial downloads
cleanup_on_error() {
    echo "🧹 Download interrupted or failed, cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 1
}
trap cleanup_on_error ERR INT TERM

# Clean up any previous temporary directory and create fresh one
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📥 Downloading Parakeet v3 models for bundling..."

# Download the required model files based on AsrModels.ModelNames
download_with_resume() {
    local url=$1
    local output=$2
    local retries=3

    for i in $(seq 1 $retries); do
        if curl -L -C - --fail --show-error -o "$output" "$url" 2>/dev/null; then
            return 0
        fi
        echo "  ⚠️  Download attempt $i/$retries failed for $output, retrying..."
        sleep 2
    done

    echo "  ❌ Failed to download $output after $retries attempts"
    return 1
}

download_model_dir() {
    local model_name=$1
    echo "Downloading $model_name..."

    # Create directory structure
    mkdir -p "$model_name/weights"
    cd "$model_name"

    # Download essential files for CoreML model
    echo "  Downloading coremldata.bin..."
    download_with_resume "$REPO_URL/$model_name/coremldata.bin" "coremldata.bin"

    echo "  Downloading metadata.json..."
    download_with_resume "$REPO_URL/$model_name/metadata.json" "metadata.json"

    echo "  Downloading model.mil..."
    download_with_resume "$REPO_URL/$model_name/model.mil" "model.mil"

    echo "  Downloading weights/weight.bin..."
    download_with_resume "$REPO_URL/$model_name/weights/weight.bin" "weights/weight.bin"

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
download_with_resume "$REPO_URL/parakeet_vocab.json" "parakeet_vocab.json"

# Download model directories
download_model_dir "Preprocessor.mlmodelc"
download_model_dir "Encoder.mlmodelc"
download_model_dir "Decoder.mlmodelc"
download_model_dir "JointDecision.mlmodelc"

echo "📋 Creating checksum for all model files..."
CHECKSUM_FILE="models.sha256"
find . -type f \( -name "*.bin" -o -name "*.json" -o -name "*.mil" \) -exec $HASH_CMD {} \; | sort > "$CHECKSUM_FILE"
echo "✅ Checksum saved to $CHECKSUM_FILE"

# Create version marker
echo "📝 Creating version marker..."
CHECKSUM_HASH=$($HASH_CMD "$CHECKSUM_FILE" | cut -d' ' -f1)
cat > "$VERSION_FILE" << EOF
VERSION=parakeet-tdt-0.6b-v3-coreml-main-$(date +%Y%m%d)
CHECKSUM_FILE=$CHECKSUM_FILE
CHECKSUM_HASH=$CHECKSUM_HASH
DOWNLOAD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SOURCE_URL=$REPO_URL
EOF

# Atomic move: only replace real directory if everything succeeded
cd ..
echo "🔄 Installing models..."
rm -rf "$MODEL_DIR.old"
[ -d "$MODEL_DIR" ] && mv "$MODEL_DIR" "$MODEL_DIR.old"
mv "$TEMP_DIR" "$MODEL_DIR"
rm -rf "$MODEL_DIR.old"

echo "🎉 All models downloaded and installed to $MODEL_DIR"
echo "📊 Model version: parakeet-tdt-0.6b-v3-coreml-main-$(date +%Y%m%d)"

# Note: Now add these files to your Xcode project as bundle resources (already configured in Package.swift)
