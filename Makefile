.PHONY: build build-xcode run run-xcode clean install install-xcode test test-xcode

# Build the application
build:
	swift build -c release

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

# Install to Applications (requires build first)
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
install-xcode: build-xcode
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