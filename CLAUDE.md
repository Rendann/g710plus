# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

### Building the macOS App Bundle (Recommended)
```bash
# Build G710Plus.app bundle (runs silently without terminal window)
./build-app.sh

# Install to Applications folder
cp -r g710plus/g710plus/G710Plus.app /Applications/

# Add to Login Items in System Preferences > Users & Groups > Login Items
# The app will start automatically on login without showing terminal windows
```

### Building Command-Line Executable (Alternative)
```bash
cd g710plus/g710plus
swiftc -o g710plus Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation
```

### Testing
```bash
# Test app bundle (silent background operation)
open G710Plus.app

# Test command-line version with verbose logging
./g710plus --verbose

# Install command-line version to system location
sudo cp g710plus /usr/local/bin/g710plus
/usr/local/bin/g710plus --verbose
```

## Architecture

This is a macOS utility that enables Logitech G710+ gaming keyboard G-keys without requiring Logitech's proprietary software. It can be built as either a command-line executable or a proper macOS app bundle that runs silently in the background. The architecture consists of three main components:

### HID Communication Layer (`g710plus.swift`)
- Uses IOKit HID framework to communicate directly with the keyboard via USB
- Targets Logitech vendor ID (0x046d) and G710+ product ID (0xc24d)
- Manages device connection/disconnection with automatic retry logic
- Handles raw USB report processing and control transfers

### Key Event Processing
- Monitors raw HID reports from the keyboard for G-key and M-key events
- Tracks key press/release state for each G-key (G1-G6) to enable proper hold/release functionality
- Translates G-key events into macOS virtual key events (F13-F18)
- Uses CoreGraphics framework to inject virtual key events into the system

### USB Protocol Implementation
The utility sends specific control transfers to configure the keyboard:
- **Address 0x0309**: Deactivates G-key "ghosting" (prevents G-keys from mirroring number keys 1-6)
- **Address 0x0306**: Controls M-mode indicator lights (M1/M2/M3 LEDs on keyboard)

## Key Components

### `G710plus` Class (singleton)
- **Device Management**: Handles IOHIDManager setup, device matching, and connection callbacks
- **Event Processing**: Processes raw HID reports and maintains key state
- **Control Operations**: Sends USB control transfers for keyboard configuration
- **Key Mapping**: Maps G1→F13, G2→F14, G3→F15, G4→F16, G5→F17, G6→F18

### `KeyCode` Enum
- Defines CGKeyCode values for F13-F18 function keys used for G-key mapping
- Based on macOS Carbon framework key codes

### `main.swift`
- Entry point that creates the singleton instance and starts the daemon thread
- Runs the main event loop to keep the utility active

## Key Event Handling

The keyboard sends specific 32-bit codes for different events:
- **M-key presses**: 0x100003 (M1), 0x200003 (M2), 0x400003 (M3)
- **G-key presses**: 0x103 (G1), 0x203 (G2), 0x403 (G3), 0x803 (G4), 0x1003 (G5), 0x2003 (G6)
- **G-key releases**: 0x3 (any G-key release - requires state tracking to determine which key)

## Installation Options

### Option 1: macOS App Bundle (Recommended)
- **Advantage**: Runs silently in background without terminal windows
- **Best for**: Users who want clean login item behavior
- **Setup**: Build with `./build-app.sh`, copy to `/Applications/`, add to Login Items

### Option 2: Command-Line Executable  
- **Advantage**: Traditional Unix-style executable
- **Best for**: Development, testing, or integration with other tools
- **Note**: Shows terminal window when used as login item

## Development Notes

- The utility must run with appropriate permissions to access HID devices
- Verbose logging is available via `--verbose` command line argument
- Device state is maintained for proper key press/release event handling
- Error handling includes retry logic for initial device connection
- Memory management includes proper cleanup on device disconnection
- Remember to update the build number in the code when applicable
- App bundle uses `LSUIElement=true` to run without dock icon or menu bar presence