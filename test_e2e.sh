#!/bin/bash
# Full e2e test for Superhoarse

set -e  # Exit on any error

# Cleanup function to restore state even on failure
cleanup() {
    echo "Performing cleanup..."
    
    # Kill the app if it's running
    if [ ! -z "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f /tmp/superhoarse_screen.png /tmp/superhoarse_test.txt
    
    # Restore Hammerspoon config if we have a backup
    if [ -f ~/.hammerspoon/init.lua.backup ]; then
        echo "Restoring original Hammerspoon configuration..."
        mv ~/.hammerspoon/init.lua.backup ~/.hammerspoon/init.lua
        killall Hammerspoon 2>/dev/null || true
        sleep 1
        open -a Hammerspoon
    elif [ "$HAMMERSPOON_CONFIG_CREATED" = "true" ]; then
        echo "Removing test Hammerspoon configuration..."
        rm -f ~/.hammerspoon/init.lua
        killall Hammerspoon 2>/dev/null || true
        sleep 1
        open -a Hammerspoon
    fi
    
    # Restore original volume if we saved it
    if [ ! -z "$ORIGINAL_VOLUME" ]; then
        echo "Restoring original volume to $ORIGINAL_VOLUME%..."
        osascript -e "set volume output volume $ORIGINAL_VOLUME" 2>/dev/null || true
    fi
}

# Set trap to run cleanup on exit
trap cleanup EXIT

# Function to calculate Levenshtein distance using a simpler approach
levenshtein() {
    local s1="$1" s2="$2"
    
    # Use Python for accurate Levenshtein calculation
    python3 -c "
import sys
def levenshtein(s1, s2):
    if len(s1) < len(s2):
        return levenshtein(s2, s1)
    
    if len(s2) == 0:
        return len(s1)
    
    previous_row = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
    
    return previous_row[-1]

print(levenshtein('$s1', '$s2'))
"
}

# Check prerequisites
echo "Checking prerequisites..."

# Configure audio output to ensure speakers work
echo "Configuring audio output..."

# Get current volume level and save it for restoration
ORIGINAL_VOLUME=$(osascript -e "output volume of (get volume settings)")
echo "Original volume: $ORIGINAL_VOLUME%"

# Set volume to a reasonable level (60%) to ensure audio is audible
echo "Setting speaker volume to 20% for test..."
osascript -e "set volume output volume 20"

# Ensure audio output is not muted
osascript -e "set volume with output muted false" 2>/dev/null || true

# Test that audio output is working by playing a brief test sound
echo "Testing audio output..."
say "Audio test" &
AUDIO_TEST_PID=$!
sleep 2
kill $AUDIO_TEST_PID 2>/dev/null || true

echo "✅ Audio configured successfully"

# Check if Hammerspoon is installed, ask user for installation if missing
if [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo "❌ Hammerspoon not found - required for e2e testing"
    echo ""
    echo "Hammerspoon is needed to simulate keyboard shortcuts for testing."
    echo "Would you like to install it automatically? (y/N)"
    read -r INSTALL_CHOICE
    
    if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
        echo "Installing Hammerspoon..."
        
        # Download and install Hammerspoon using Homebrew (most reliable method)
        if command -v brew >/dev/null 2>&1; then
            echo "Installing Hammerspoon via Homebrew..."
            brew install --cask hammerspoon
        else
            echo "Homebrew not found. Would you like to install Homebrew first? (y/N)"
            read -r INSTALL_BREW
            
            if [[ "$INSTALL_BREW" =~ ^[Yy]$ ]]; then
                echo "Installing Homebrew first, then Hammerspoon..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Add brew to PATH for this session
                eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
                brew install --cask hammerspoon
            else
                echo "❌ Cannot proceed without Homebrew. Please install Hammerspoon manually:"
                echo "   1. Visit https://www.hammerspoon.org/"
                echo "   2. Download and install Hammerspoon"
                echo "   3. Run this test script again"
                exit 1
            fi
        fi
        
        echo "✅ Hammerspoon installed successfully"
    else
        echo "❌ Cannot proceed without Hammerspoon. Please install it manually:"
        echo "   1. Visit https://www.hammerspoon.org/"
        echo "   2. Download and install Hammerspoon"
        echo "   3. Run this test script again"
        echo ""
        echo "Alternatively, you can install via Homebrew:"
        echo "   brew install --cask hammerspoon"
        exit 1
    fi
fi

# Check if Hammerspoon is running
if ! pgrep -f "Hammerspoon" > /dev/null; then
    echo "Starting Hammerspoon..."
    open -a Hammerspoon
    sleep 2
fi

# Enable IPC automatically
echo "Setting up Hammerspoon IPC..."
mkdir -p ~/.hammerspoon

# Backup existing config if it exists
if [ -f ~/.hammerspoon/init.lua ]; then
    echo "Backing up existing Hammerspoon configuration..."
    cp ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup
else
    HAMMERSPOON_CONFIG_CREATED=true
fi

cat > ~/.hammerspoon/init.lua << 'EOF'
-- Enable IPC for testing
hs.ipc.cliInstall()
print("Hammerspoon IPC enabled for testing")
EOF

# Restart Hammerspoon to load IPC
killall Hammerspoon 2>/dev/null || true
sleep 1
open -a Hammerspoon
echo "Waiting for Hammerspoon to start..."
sleep 3

# Test IPC connection and handle accessibility permissions
if ! /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'print("IPC test")' > /dev/null 2>&1; then
    echo "⚠️  Hammerspoon needs accessibility permissions to continue."
    echo "🔧 Opening System Preferences to grant permissions..."
    
    # Open System Preferences to the right location
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    
    echo "📋 Please:"
    echo "  1. Click the lock icon and enter your password"
    echo "  2. Find and check 'Hammerspoon' in the list"
    echo "  3. Close System Preferences"
    echo ""
    echo "⏳ Waiting for accessibility permissions (checking every 5 seconds)..."
    
    # Poll for accessibility permissions
    PERMISSION_GRANTED=false
    for i in {1..24}; do  # Wait up to 2 minutes
        sleep 5
        if /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'print("IPC test")' > /dev/null 2>&1; then
            PERMISSION_GRANTED=true
            break
        fi
        echo "  Still waiting... (attempt $i/24)"
    done
    
    if [ "$PERMISSION_GRANTED" = false ]; then
        echo "❌ Hammerspoon accessibility permissions not granted after 2 minutes."
        echo "Please grant accessibility permissions and run the test again."
        exit 1
    fi
    
    echo "✅ Hammerspoon accessibility permissions granted!"
fi

echo "✅ Prerequisites checked successfully"

# 1. Kill any existing instances
echo "Killing existing Superhoarse instances..."
pkill -f Superhoarse || echo "No running instances"

# 2. Build the app
echo "Building Superhoarse..."
swift build -c release
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# 3. Start the app
echo "Starting Superhoarse..."
swift run &
APP_PID=$!

# 4. Wait for model to load (use generous timeout)
echo "Waiting for Parakeet model to load (60 seconds timeout)..."
sleep 60
echo "Assuming model is loaded after 60 seconds"

# 5. Clear clipboard and run test
echo "Clearing clipboard and running functionality test..."
echo "" | pbcopy

# Use Hammerspoon IPC directly
echo "Executing test commands via Hammerspoon IPC..."

# Start recording
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'hs.eventtap.keyStroke({"alt"}, "space"); print("Started recording")'

# Wait and generate speech
sleep 1
say 'End to end test successful' &

# Wait for speech to complete then stop recording  
sleep 3
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'hs.eventtap.keyStroke({"alt"}, "space"); print("Stopped recording")'

# Wait for test completion and verify results
sleep 6
CLIPBOARD_CONTENT=$(pbpaste)

# Use fuzzy matching with Levenshtein distance
EXPECTED="End to end test successful."
DISTANCE=$(levenshtein "$CLIPBOARD_CONTENT" "$EXPECTED")
MAX_DISTANCE=5  # Allow up to 5 character differences

if [[ $DISTANCE -le $MAX_DISTANCE ]]; then
    echo "✅ E2E Test PASSED: Speech recognition working correctly"
    echo "Expected: '$EXPECTED'"
    echo "Got:      '$CLIPBOARD_CONTENT'"
    echo "Levenshtein distance: $DISTANCE (≤ $MAX_DISTANCE allowed)"
else
    echo "❌ E2E Test FAILED: Transcription too different from expected"
    echo "Expected: '$EXPECTED'"
    echo "Got:      '$CLIPBOARD_CONTENT'" 
    echo "Levenshtein distance: $DISTANCE (> $MAX_DISTANCE allowed)"
    exit 1
fi

echo "✅ E2E test completed successfully!"
echo "Your original Hammerspoon configuration and audio settings will be restored by the cleanup function."
