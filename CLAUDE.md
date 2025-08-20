# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift command-line utility that enables the G1-G6 keys on a Logitech G710+ gaming keyboard to work on macOS without installing Logitech's Gaming Software. The tool communicates directly with the keyboard via USB/HID to:

- Disable key mirroring (G-keys normally mirror number keys 1-6)
- Map G-keys to F13-F18 function keys with hold/release functionality
- Control M-mode indicator lights on the keyboard

## Build Commands

This project builds a macOS command-line executable using Swift:

```bash
# Build from command line (recommended)
cd g710plus/g710plus/g710plus
swiftc -o g710plus Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation

# Build with Xcode (alternative)
xcodebuild -project g710plus/g710plus.xcodeproj -target g710plus build
```

## Installation and Auto-Start Setup

### Manual Installation

1. Build the executable (see above)
2. Copy to system location: `sudo cp g710plus /usr/local/bin/g710plus`
3. Test it works: `/usr/local/bin/g710plus --verbose` (no sudo needed!)

### Auto-Start on Login (Launch Agent)

To have the utility start automatically when you log in (recommended approach):

1. Create a Launch Agent plist file:
```bash
tee ~/Library/LaunchAgents/com.halo.g710plus.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>com.halo.g710plus</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/bin/g710plus</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF
```

2. Load the Launch Agent:
```bash
# Using the provided example file
cp launch-agent-example.plist ~/Library/LaunchAgents/com.halo.g710plus.plist
launchctl load ~/Library/LaunchAgents/com.halo.g710plus.plist

# Or create manually (alternative method shown above)
```

3. Manage the Launch Agent:
```bash
# Stop: launchctl unload ~/Library/LaunchAgents/com.halo.g710plus.plist
# Start: launchctl load ~/Library/LaunchAgents/com.halo.g710plus.plist
# Remove: rm ~/Library/LaunchAgents/com.halo.g710plus.plist
```

**Benefits of Launch Agent approach:**
- No root access required (safer)
- User-specific configuration
- Simpler management (no sudo needed)
- Starts when you log in (when you need the keyboard)

## Architecture

### Core Files
- `main.swift` - Entry point that starts the daemon thread
- `g710plus.swift` - Main class containing USB communication and key mapping logic
- `KeyCodes.swift` - Enum defining macOS keypad key codes

### Key Components

**G710plus Class (singleton)**
- Manages IOKit HID communication with keyboard (vendor ID: 0x046d, product ID: 0xc24d)
- Handles device connection/removal callbacks
- Processes input reports from keyboard
- Maps G-keys to F13-F18 function keys with hold/release functionality:
  - G1 → F13 (hold/release supported)
  - G2 → F14 (hold/release supported)
  - G3 → F15 (hold/release supported)
  - G4 → F16 (hold/release supported)
  - G5 → F17 (hold/release supported)
  - G6 → F18 (hold/release supported)
- M-keys still control mode switching and indicator lights

**Key Functions**
- `deactivateGhosting()` - Sends USB control transfer to disable G-key mirroring
- `setMLight()` - Controls M-mode indicator lights  
- `sendKeyEvent()` - Simulates key down/up events for hold/release functionality
- `input()` - Processes HID reports and handles G-key press/release detection

### USB Communication
Uses IOKit HID framework for low-level USB communication. The keyboard requires specific control transfers to modify its behavior without proprietary drivers.
- I never want to do a manual process to get this utility running. It needs to be automated.