# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

### Building the Application
```bash
# Build G710Plus.app bundle (production)
./build-app.sh

# Build debug version with verbose logging
./build-app-debug.sh

# Build command-line executable
cd g710plus/g710plus && swiftc -o g710plus Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation
```

### Testing Commands
```bash
# Test configuration loading
./G710Plus.app/Contents/MacOS/G710Plus --config /path/to/test-config.json --verbose

# Monitor configuration logs
log stream --predicate 'subsystem == "com.halo.g710plus"' --info --debug | grep -i config

# Test invalid configurations (validates error handling)
./G710Plus.app/Contents/MacOS/G710Plus --config invalid-config.json --verbose
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
- Translates G-key events into configurable macOS virtual key events via JSON configuration system
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
- **Configurable Key Mapping**: Uses `ConfigurationManager` to load custom key mappings from JSON files
- **Default Key Mappings** (when no custom config):
  - G1 → Control+Command+Shift+L
  - G2 → Control+Command+Shift+K
  - G3 → Control+Command+Shift+J
  - G4 → F16, G5 → F17, G6 → F18

### `KeyCode` Enum
- Defines CGKeyCode values for comprehensive keyboard mapping:
  - Letters A-Z, Numbers 0-9, Function keys F1-F18
  - Special keys (Space, Enter, Tab, Escape, Backspace, Delete)
  - Arrow keys, Punctuation, Keypad keys
- Based on macOS Carbon framework key codes
- Supports dynamic character-to-KeyCode mapping system

### `GKeyConfiguration` System (`GKeyConfig.swift`)
- **`GKeyConfiguration`**: Codable struct defining mappings for all 6 G-keys
- **`KeyMapping`**: Individual key configuration with character and modifier support
- **`ConfigurationManager`**: Singleton that loads and manages configuration from multiple sources:
  - Command-line `--config` argument path
  - App bundle: `g710plus-config.json`
  - Home directory: `~/.g710plus-config.json`
  - Built-in defaults as fallback
- **Character-to-KeyCode Mapping**: Dynamic system supporting:
  - Lowercase letters: `"k"` → types 'k'
  - Explicit shift modifiers: `"k"` + `["shift"]` → types 'K'
  - Special keys: `"Space"`, `"Enter"`, `"ArrowUp"`, `"F13"`, etc.
  - Modifier validation: `control/ctrl`, `command/cmd`, `shift`, `option/alt`

### `main.swift`
- Entry point that creates the singleton instance and starts the daemon thread
- Initializes `ConfigurationManager` early to ensure proper config loading
- Handles command-line arguments including `--config`, `--verbose`, `--version`, `--help`
- Runs the main event loop to keep the utility active

## Key Event Handling

The keyboard sends specific 32-bit codes for different events:
- **M-key presses**: 0x100003 (M1), 0x200003 (M2), 0x400003 (M3)
- **G-key presses**: 0x103 (G1), 0x203 (G2), 0x403 (G3), 0x803 (G4), 0x1003 (G5), 0x2003 (G6)
- **G-key releases**: 0x3 (any G-key release - requires state tracking to determine which key)

## JSON Configuration System

G-keys are fully customizable via JSON configuration files that define what keys/shortcuts each G-key sends.

### Configuration File Format
```json
{
  "g1": {"key": "k", "modifiers": []},
  "g2": {"key": "k", "modifiers": ["shift"]},
  "g3": {"key": "Space", "modifiers": ["command"]},
  "g4": {"key": "F13", "modifiers": []},
  "g5": {"key": "Enter", "modifiers": []},
  "g6": {"key": "Escape", "modifiers": []}
}
```

### Configuration Priority (checked in order)
1. **Custom path**: `--config /path/to/config.json` command line argument
2. **App bundle**: `G710Plus.app/Contents/Resources/g710plus-config.json` 
3. **Home directory**: `~/.g710plus-config.json`
4. **Built-in defaults**: Hardcoded fallback configuration

### Supported Keys
- **Letters**: `"k"` (lowercase only - use `["shift"]` for uppercase)
- **Numbers**: `"0"` through `"9"`
- **Function Keys**: `"F1"` through `"F18"`
- **Special Keys**: `"Space"`, `"Enter"`, `"Tab"`, `"Escape"`, `"Backspace"`, `"Delete"`
- **Arrow Keys**: `"ArrowUp"`, `"ArrowDown"`, `"ArrowLeft"`, `"ArrowRight"`
- **Punctuation**: `";"`, `","`, `"."`, `"/"`, `"\\"`, `"'"`, `"["`, `"]"`, `"-"`, `"="`, `` "`" ``

### Supported Modifiers
- `"control"` or `"ctrl"` - Control key
- `"command"` or `"cmd"` - Command key (⌘)
- `"shift"` - Shift key  
- `"option"` or `"alt"` - Option/Alt key

### Important Configuration Rules
- **No uppercase letters**: Use lowercase + explicit `["shift"]` modifier
- **No auto-shift**: Shifted symbols like `"!"` not supported - use `"1"` + `["shift"]`
- **Explicit modifiers**: All modifiers must be explicitly specified
- **Restart required**: Configuration changes require app restart to take effect

### Configuration Error Handling
The system provides helpful error messages for invalid configurations:
- Uppercase letters: `"ERROR - Uppercase letter 'K' not allowed for g2. Use 'k' with "shift" modifier instead."`
- Invalid keys: `"ERROR - Invalid key configuration 'InvalidKey' for g1"`

## Code Signing and Development Setup

### Automatic Code Signing
- Build script detects Apple Development certificate via `security find-identity`
- Signs with `codesign --force --sign "$SIGNING_IDENTITY" "G710Plus.app"`
- Prevents TCC permission re-authorization after rebuilds

### Development Certificate Setup
Requires Xcode with Apple ID sign-in for Apple Development certificate.

### TCC Permission Requirements
- **Input Monitoring**: Required for G-key detection
- **Accessibility**: May be required for virtual key injection
- Code signing prevents permission reset on rebuild

## Development Guidelines

### Swift Coding Standards
- Use singleton pattern for `G710plus` and `ConfigurationManager` classes
- Implement proper error handling with helpful user messages
- Follow Apple's logging best practices with `os_log`
- Use `Codable` for JSON configuration parsing
- Maintain explicit key state tracking for press/release events

### Configuration System Testing
```bash
# Test configuration priority loading
./G710Plus.app/Contents/MacOS/G710Plus --config /path/to/test-config.json --verbose

# Validate error handling for invalid configs
./G710Plus.app/Contents/MacOS/G710Plus --config invalid-config.json --verbose

# Monitor configuration loading via logs
log stream --predicate 'subsystem == "com.halo.g710plus"' --info --debug | grep -i config
```

### Testing Conventions
- Test configuration priority: custom → bundle → home → defaults
- Validate lowercase vs explicit shift modifier behavior
- Verify error messages for uppercase letters and invalid keys
- Ensure configuration changes require app restart
- Test HID device connection/disconnection scenarios

### Memory Management
- Proper cleanup on device disconnection
- Early initialization of `ConfigurationManager` to prevent loading issues
- State tracking for G-key press/release events

### Logging Implementation
- `logInfo(_:)`: Essential operational messages (always enabled)
- `logDebug(_:)`: Diagnostic information (requires `VERBOSE_LOGGING` flag)
- Expected control transfer failures (-536850432) during connection are normal

### Build Configuration
- Standard build: Info-level logging only
- Debug build: Enables `VERBOSE_LOGGING` compilation flag
- App bundle uses `LSUIElement=true` for background operation