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
	@echo "Killing existing Superhoarse processes..."
	-pkill -f "Superhoarse" || true
	@echo "Creating application bundle..."
	mkdir -p Superhoarse.app/Contents/MacOS
	mkdir -p Superhoarse.app/Contents/Resources
	cp .build/release/Superhoarse Superhoarse.app/Contents/MacOS/
	cp Info.plist Superhoarse.app/Contents/
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

# Development setup
setup:
	@echo "Setting up development environment..."
	@echo "Make sure you have Xcode Command Line Tools installed:"
	@echo "xcode-select --install"
	@echo ""
	@echo "To build: make build"
	@echo "To run: make run" 
	@echo "To install: make install"