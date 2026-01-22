.PHONY: build build-xcode run run-xcode clean install install-xcode test test-xcode check-models models update-models dist brew-install brew-uninstall

# Build the application
build: check-models
	swift build -c release --disable-sandbox

# Build with Xcode
build-xcode:
	xcodebuild -project superhoarse.xcodeproj -scheme superhoarse -configuration Release build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	@echo "Manually signing app for local execution..."
	@BUILT_APP=$$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Release/superhoarse.app" -type d 2>/dev/null | head -1); \
	if [ ! -z "$$BUILT_APP" ]; then \
		codesign --force --deep --sign - "$$BUILT_APP" || echo "Warning: Could not sign app, proceeding anyway..."; \
	fi

# Run in development mode
run:
	swift run

# Build and run with Xcode
run-xcode:
	./run-xcode.sh

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Fast check using version marker (runs every build)
check-models:
	@if [ ! -f "Sources/Resources/.models_version" ]; then \
		echo "⚠️  Models not found, downloading..."; \
		$(MAKE) models; \
	else \
		if command -v sha256sum >/dev/null 2>&1; then \
			HASH_CMD="sha256sum"; \
		else \
			HASH_CMD="shasum -a 256"; \
		fi; \
		EXPECTED_HASH=$$(cat Sources/Resources/.models_version | grep CHECKSUM_HASH | cut -d= -f2); \
		ACTUAL_HASH=$$($$HASH_CMD Sources/Resources/models.sha256 2>/dev/null | cut -d' ' -f1 || echo "missing"); \
		if [ "$$EXPECTED_HASH" != "$$ACTUAL_HASH" ]; then \
			echo "⚠️  Model checksum changed, re-validating..."; \
			$(MAKE) models; \
		else \
			echo "✅ Models validated (fast check)"; \
		fi \
	fi

# Full model validation and download
models:
	@echo "🔍 Validating model files..."
	@if [ -f "Sources/Resources/models.sha256" ]; then \
		if command -v sha256sum >/dev/null 2>&1; then \
			HASH_CMD="sha256sum"; \
		else \
			HASH_CMD="shasum -a 256"; \
		fi; \
		cd Sources/Resources && $$HASH_CMD -c models.sha256 >/dev/null 2>&1 && STATUS=$$? || STATUS=$$?; \
		if [ $$STATUS -eq 0 ]; then \
			echo "✅ All models verified, updating version marker..."; \
			CHECKSUM_HASH=$$($$HASH_CMD models.sha256 | cut -d' ' -f1); \
			if [ -f ".models_version" ]; then \
				if command -v sed >/dev/null 2>&1 && sed --version 2>&1 | grep -q GNU; then \
					sed -i "s/CHECKSUM_HASH=.*/CHECKSUM_HASH=$$CHECKSUM_HASH/" .models_version; \
				else \
					sed -i '' "s/CHECKSUM_HASH=.*/CHECKSUM_HASH=$$CHECKSUM_HASH/" .models_version; \
				fi; \
			else \
				echo "📝 Creating version marker..."; \
				echo "VERSION=parakeet-tdt-0.6b-v2-coreml-main-$$(date +%Y%m%d)" > .models_version; \
				echo "CHECKSUM_FILE=models.sha256" >> .models_version; \
				echo "CHECKSUM_HASH=$$CHECKSUM_HASH" >> .models_version; \
				echo "DOWNLOAD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .models_version; \
				echo "SOURCE_URL=https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml/resolve/main" >> .models_version; \
			fi; \
			cd ../..; \
		else \
			echo "❌ Model verification failed, re-downloading..."; \
			cd ../..; \
			./download_models.sh; \
		fi \
	else \
		echo "⬇️  Models missing, downloading..."; \
		./download_models.sh; \
	fi

# Force re-download of models
update-models:
	@echo "🔄 Forcing model re-download..."
	@echo "This will delete existing models and download latest from HuggingFace"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if echo "$$REPLY" | grep -iq "^y"; then \
		rm -rf Sources/Resources; \
		./download_models.sh; \
		echo "✅ Models updated successfully"; \
		echo "📝 Remember to commit Sources/Resources/models.sha256 if checksums changed"; \
	else \
		echo "❌ Update cancelled"; \
	fi

# Install to Applications (requires build, which includes model check)
install: build
	@echo "Killing existing Superhoarse processes..."
	-pkill -f "Superhoarse" || true
	@echo "Creating application bundle..."
	mkdir -p Superhoarse.app/Contents/MacOS
	mkdir -p Superhoarse.app/Contents/Resources
	cp .build/release/Superhoarse Superhoarse.app/Contents/MacOS/
	cp Info.plist Superhoarse.app/Contents/
	cp -R Sources/Resources/* Superhoarse.app/Contents/Resources/
	@echo "Setting proper permissions..."
	chmod +x Superhoarse.app/Contents/MacOS/Superhoarse
	@echo "Removing existing installation..."
	sudo rm -rf /Applications/Superhoarse.app
	@echo "Installing to /Applications..."
	sudo cp -R Superhoarse.app /Applications/
	@echo "Setting ownership to current user..."
	sudo chown -R $(USER):staff /Applications/Superhoarse.app
	@echo "Superhoarse installed successfully!"
	@echo ""
	@echo "You can now launch from /Applications/Superhoarse.app"

# Install Xcode-built version to Applications
install-xcode: check-models build-xcode
	@echo "Killing existing Superhoarse processes..."
	-pkill -f "Superhoarse" || true
	@echo "Locating Xcode-built app..."
	@BUILT_APP=$$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Release/superhoarse.app" -type d 2>/dev/null | head -1); \
	if [ -z "$$BUILT_APP" ]; then \
		echo "Error: Could not find Xcode-built app in DerivedData"; \
		exit 1; \
	fi; \
	echo "Found Xcode-built app at: $$BUILT_APP"; \
	echo "Removing existing installation..."; \
	sudo rm -rf /Applications/Superhoarse.app; \
	echo "Installing Xcode-built version to /Applications..."; \
	sudo cp -R "$$BUILT_APP" /Applications/Superhoarse.app; \
	echo "Setting ownership to current user..."; \
	sudo chown -R $(USER):staff /Applications/Superhoarse.app; \
	echo "Superhoarse (Xcode-built) installed successfully!"; \
	echo ""; \
	echo "You can now launch from /Applications/Superhoarse.app"

# Development setup
setup:
	@echo "Setting up development environment..."
	@echo "Make sure you have Xcode Command Line Tools installed:"
	@echo "xcode-select --install"
	@echo ""
	@echo "To build: make build"
	@echo "To run: make run"
	@echo "To install: make install"

# Create distributable zip for Homebrew Cask or manual distribution
dist: build
	@echo "Creating distributable package..."
	rm -rf dist
	mkdir -p dist/Superhoarse.app/Contents/MacOS
	mkdir -p dist/Superhoarse.app/Contents/Resources
	cp .build/release/Superhoarse dist/Superhoarse.app/Contents/MacOS/
	cp Info.plist dist/Superhoarse.app/Contents/
	cp -R Sources/Resources/* dist/Superhoarse.app/Contents/Resources/
	chmod +x dist/Superhoarse.app/Contents/MacOS/Superhoarse
	@echo "Signing app for local execution..."
	codesign --force --deep --sign - dist/Superhoarse.app || echo "Warning: Could not sign app"
	cd dist && zip -r Superhoarse-$(shell git describe --tags 2>/dev/null || echo "1.0.0").zip Superhoarse.app
	@echo "✅ Distribution package created: dist/Superhoarse-*.zip"
	@echo "📊 Size: $$(du -h dist/*.zip | cut -f1)"

# Install via local Homebrew formula
brew-install:
	@echo "Installing Superhoarse via Homebrew formula..."
	brew install --formula Formula/superhoarse.rb

# Uninstall Homebrew installation
brew-uninstall:
	@echo "Uninstalling Superhoarse from Homebrew..."
	brew uninstall superhoarse || true