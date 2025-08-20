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
3. Test it works: `sudo /usr/local/bin/g710plus --verbose`

### Auto-Start on Boot (Launch Daemon)

To have the utility start automatically when your Mac boots:

1. Create a Launch Daemon plist file:
```bash
sudo tee /Library/LaunchDaemons/com.halo.g710plus.daemon.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.halo.g710plus.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/g710plus</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/g710plus.err</string>
    <key>StandardOutPath</key>
    <string>/var/log/g710plus.out</string>
</dict>
</plist>
EOF
```

2. Load the daemon:
```bash
sudo launchctl load /Library/LaunchDaemons/com.halo.g710plus.daemon.plist
```

3. Manage the daemon:
```bash
# Stop: sudo launchctl unload /Library/LaunchDaemons/com.halo.g710plus.daemon.plist
# Start: sudo launchctl load /Library/LaunchDaemons/com.halo.g710plus.daemon.plist
# Remove: sudo rm /Library/LaunchDaemons/com.halo.g710plus.daemon.plist
```

### Check Logs
```bash
# View output logs
cat /var/log/g710plus.out

# View error logs  
cat /var/log/g710plus.err
```

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