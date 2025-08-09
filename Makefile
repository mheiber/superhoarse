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
	@echo "Killing existing SuperWhisperLite processes..."
	-pkill -f "SuperWhisperLite" || true
	@echo "Creating application bundle..."
	mkdir -p SuperWhisperLite.app/Contents/MacOS
	mkdir -p SuperWhisperLite.app/Contents/Resources
	cp .build/release/SuperWhisperLite SuperWhisperLite.app/Contents/MacOS/
	cp Info.plist SuperWhisperLite.app/Contents/
	@echo "Setting proper permissions..."
	chmod +x SuperWhisperLite.app/Contents/MacOS/SuperWhisperLite
	@echo "Removing existing installation..."
	sudo rm -rf /Applications/SuperWhisperLite.app
	@echo "Installing to /Applications..."
	sudo cp -R SuperWhisperLite.app /Applications/
	@echo "Setting ownership to current user..."
	sudo chown -R $(USER):staff /Applications/SuperWhisperLite.app
	@echo "SuperWhisper Lite installed successfully!"
	@echo ""
	@echo "You can now launch from /Applications/SuperWhisperLite.app"

# Development setup
setup:
	@echo "Setting up development environment..."
	@echo "Make sure you have Xcode Command Line Tools installed:"
	@echo "xcode-select --install"
	@echo ""
	@echo "To build: make build"
	@echo "To run: make run" 
	@echo "To install: make install"