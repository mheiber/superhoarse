# Contributing to Superhoarse

## Manual Testing

### Prerequisites
Before testing, ensure you have:
- Superhoarse app installed and running
- Hammerspoon app installed and running  
- Both apps have accessibility permissions granted in System Preferences > Privacy & Security > Accessibility

user flows are documented in ./user_flows.md

### End-to-End Test

Complete automated test that builds and tests the app from scratch.

**Prerequisites:**
- Install [Hammerspoon](https://www.hammerspoon.org/) and grant it accessibility permissions
- Ensure you have speakers/headphones (volume will be set automatically)

**Run the test:**
```bash
./test_e2e.sh
```

The script automatically:
- Sets speaker volume and configures Hammerspoon 
- Builds and starts the app, waits for model loading
- Tests speech recognition with fuzzy matching validation
- Cleans up and restores your Hammerspoon config

**Expected output:**
```
✅ E2E test completed successfully!
Your original Hammerspoon configuration has been restored.
```

### Basic Functionality Test

To test just the core voice-to-text functionality (assumes app is already running):

```bash
# 1. Create Hammerspoon test configuration
cat > ~/.hammerspoon/init.lua << 'EOF'
-- Enable IPC
hs.ipc.cliInstall()

-- Test Superhoarse functionality
print("Testing Superhoarse app...")

-- Press Option+Space to start recording
hs.eventtap.keyStroke({"alt"}, "space")
print("Pressed Option+Space to start recording")

-- Wait briefly then generate speech
hs.timer.doAfter(1, function()
    os.execute("say 'Testing speech recognition functionality'")
    print("Generated test speech")
    
    -- Wait for speech to complete then stop recording
    hs.timer.doAfter(3, function()
        hs.eventtap.keyStroke({"alt"}, "space") 
        print("Pressed Option+Space to stop recording")
    end)
end)
EOF

# 2. Restart Hammerspoon to execute the test
killall Hammerspoon && sleep 1 && open -a Hammerspoon

# 3. Wait for test completion and verify results
sleep 6 && echo "Clipboard contents:" && pbpaste
```

**Expected Result:** The clipboard should contain "Testing speech recognition functionality."

### Troubleshooting

If the test fails:

1. **Check app status:** Verify both Superhoarse and Hammerspoon are running:
   ```bash
   ps aux | grep -E "(Superhoarse|Hammerspoon)" | grep -v grep
   ```

2. **Check accessibility permissions:** Both apps must have accessibility permissions granted

3. **Check hotkey configuration:** Default hotkey is Option+Space (⌥+Space)

4. **Manual test:** Try pressing Option+Space manually, speak, then press Option+Space again

### Clean Up

After testing, restore your Hammerspoon configuration:
```bash
# Remove test configuration
rm ~/.hammerspoon/init.lua
# Restart Hammerspoon
killall Hammerspoon && open -a Hammerspoon
```
