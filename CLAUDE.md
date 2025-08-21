# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

### Building the macOS App Bundle (Recommended)
```bash
# Build G710Plus.app bundle (runs silently without terminal window)
./build-app.sh

# Build debug version with verbose logging enabled
./build-app-debug.sh

# Install to Applications folder
cp -r g710plus/g710plus/G710Plus.app /Applications/

# Add to Login Items in System Preferences > Users & Groups > Login Items
# The app will start automatically on login without showing terminal windows
```

**Build Script Features:**
- Automatic code signing with Apple Development certificate
- Creates proper app bundle structure with Info.plist
- Standard build: Info-level logging only
- Debug build: Enables verbose debug logging via `VERBOSE_LOGGING` flag

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
- **Key Mapping**: 
  - G1 → Control+Command+Shift+L
  - G2 → Control+Command+Shift+K
  - G3 → Control+Command+Shift+J
  - G4 → F16, G5 → F17, G6 → F18

### `KeyCode` Enum
- Defines CGKeyCode values for F13-F18 function keys and L/K/J letter keys used for G-key mapping
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

## Code Signing

The app bundle requires proper code signing to avoid TCC permission re-authorization after each rebuild. The `build-app.sh` script automatically handles this:

### Automatic Code Signing
- Build script detects your Apple Development certificate via `security find-identity`
- Signs the app bundle with `codesign --force --sign "$SIGNING_IDENTITY" "G710Plus.app"`
- Prevents TCC from treating each rebuild as a "new" application requiring re-authorization

### Setting Up Development Certificate
If you don't have an Apple Development certificate:
1. Open Xcode and sign in with your Apple ID (Xcode > Preferences > Accounts)
2. Select your team and ensure "Apple Development" certificate is available
3. Alternatively: enable "Automatically manage signing" in the Xcode project settings

### Troubleshooting Code Signing
- **Warning "No development certificate found"**: Install Xcode and sign in with Apple ID
- **TCC permissions reset after rebuild**: Code signing failed or different certificate used
- **Verify signing**: `codesign -dv --verbose=4 G710Plus.app`

## Logging System

The utility uses macOS unified logging (`os_log`) for robust logging that integrates with Console.app:

### Log Levels
- **Info Level**: Essential operational messages (device connection, errors)
- **Debug Level**: Detailed diagnostic information (only when `--verbose` flag is used)

### Viewing Logs
**Console.app Method:**
1. Open Console.app (Applications > Utilities)
2. Filter by process name: "g710plus" or "G710Plus"
3. Use predicate: `subsystem == "com.halo.g710plus"`

**Command Line Method:**
```bash
# View all g710plus logs
log show --predicate 'subsystem == "com.halo.g710plus"' --info --debug --last 1h

# Follow live logs
log stream --predicate 'subsystem == "com.halo.g710plus"' --info --debug
```

### Build-Time Logging Configuration
- **Standard Build**: Info-level messages only
- **Debug Build** (`./build-app-debug.sh`): Enables verbose debug logging via `VERBOSE_LOGGING` compilation flag

### Logging Implementation
The utility implements two main logging functions:
- `logInfo(_:)`: Always logs important operational messages
- `logDebug(_:)`: Conditional logging based on `VERBOSE_LOGGING` flag

**Expected Messages:** Control transfer failures (-536850432) during device connection are normal and do not impact G-key functionality.

## TCC Permissions

macOS Transparency, Consent, and Control (TCC) system requires explicit permission grants for HID device access:

### Required Permissions
**Input Monitoring**: Required for detecting G-key presses
- Location: System Settings > Privacy & Security > Input Monitoring
- Enable: G710Plus.app (or g710plus if using command-line version)

**Accessibility** (if prompted): May be required for virtual key event injection
- Location: System Settings > Privacy & Security > Accessibility  
- Enable: G710Plus.app when prompted

### Permission Process
1. **First Launch**: macOS prompts for Input Monitoring permission
2. **Grant Permission**: Check the box next to G710Plus in System Settings
3. **Restart App**: Quit and relaunch for permissions to take effect
4. **Additional Prompts**: Grant Accessibility permission if requested

### Permission Descriptions (Info.plist)
The app bundle includes user-friendly permission descriptions:
```xml
<key>NSInputMonitoringUsageDescription</key>
<string>G710Plus needs to monitor keyboard input to detect G-key presses on your Logitech G710+ keyboard and map them to function keys.</string>
```

### Troubleshooting TCC Issues
- **G-keys output numbers instead of F13-F18**: Input Monitoring permission not granted
- **No G-key response at all**: App not running or HID device access denied
- **Permissions reset after rebuild**: Code signing issue (see Code Signing section)
- **Manual permission reset**: Remove app from TCC settings, rebuild, re-authorize

## Development Notes

- The utility must run with appropriate permissions to access HID devices
- Verbose logging is available via `--verbose` command line argument
- Device state is maintained for proper key press/release event handling
- Error handling includes retry logic for initial device connection
- Memory management includes proper cleanup on device disconnection
- Remember to update the build number in the code when applicable
- App bundle uses `LSUIElement=true` to run without dock icon or menu bar presence