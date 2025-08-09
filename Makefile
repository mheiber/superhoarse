.PHONY: build run clean install

# Build the application
build:
	swift build -c release

# Run in development mode
run:
	swift run

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Install to Applications (requires build first)
install: build
	@echo "Creating application bundle..."
	mkdir -p SuperWhisperLite.app/Contents/MacOS
	mkdir -p SuperWhisperLite.app/Contents/Resources
	cp .build/release/SuperWhisperLite SuperWhisperLite.app/Contents/MacOS/
	cp Info.plist SuperWhisperLite.app/Contents/
	@echo "Installing to /Applications..."
	sudo cp -R SuperWhisperLite.app /Applications/
	@echo "SuperWhisper Lite installed successfully!"

# Development setup
setup:
	@echo "Setting up development environment..."
	@echo "Make sure you have Xcode Command Line Tools installed:"
	@echo "xcode-select --install"
	@echo ""
	@echo "To build: make build"
	@echo "To run: make run" 
	@echo "To install: make install"