#!/bin/bash
# Full e2e test for Superhoarse

set -e  # Exit on any error

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

# Set speaker volume to ensure audio works
echo "Setting speaker volume to 50%..."
osascript -e "set volume output volume 50"

# Check if Hammerspoon is installed
if [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo "❌ Hammerspoon.app not found in /Applications"
    echo "Please install Hammerspoon from https://www.hammerspoon.org/"
    exit 1
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

# Test IPC connection
if ! /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'print("IPC test")' > /dev/null 2>&1; then
    echo "❌ Hammerspoon IPC not working. Please ensure Hammerspoon has accessibility permissions."
    exit 1
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

# Cleanup and restore user's Hammerspoon config
echo "Cleaning up..."
kill $APP_PID 2>/dev/null || true
rm -f /tmp/superhoarse_screen.png /tmp/superhoarse_text.txt

# Restore user's original Hammerspoon config
if [ -f ~/.hammerspoon/init.lua.backup ]; then
    echo "Restoring original Hammerspoon configuration..."
    mv ~/.hammerspoon/init.lua.backup ~/.hammerspoon/init.lua
else
    echo "Removing test Hammerspoon configuration..."
    rm -f ~/.hammerspoon/init.lua
fi

# Restart Hammerspoon to restore original state
killall Hammerspoon 2>/dev/null || true
sleep 1
open -a Hammerspoon

echo "✅ E2E test completed successfully!"
echo "Your original Hammerspoon configuration has been restored."