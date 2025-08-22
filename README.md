## Logitech G710+ without "Gaming Software"

**TL;DR**

Run this command line tool on **macOS** to use the **G1-6 keys** of the Logitech **G710+ gaming keyboard** without installing proprietary Software by Logitech.

**✅ Tested on macOS Sequoia 15.6** - Fully compatible with modern macOS security requirements.

### Introduction

So you just bought this gaming keyboard and realize "oh no, the G-keys don't work without the Logitech spyware drivers :("

"No problem", you say, "I'll install [https://github.com/tekezo/Karabiner/](Karabiner) and remap them manually" - only to find out that the G-keys simply mirror the numeric 1-6 keys, which makes them indistinguishable.

Digging in deeper, you might find out that [someone reverse engineered](https://github.com/K900/g710) the USB communication of the keyboard. It turns out that you can instruct the keyboard to stop mirroring the number keys.

### How it works

This is a simple command line application written in Swift that communicates directly via USB with your keyboard and does the following:

* Disables G-key mirroring (G-keys normally mirror number keys 1-6)
* Maps G-keys to customizable shortcuts via JSON configuration (default mappings):
  - G1 → Control+Command+Shift+L
  - G2 → Control+Command+Shift+K  
  - G3 → Control+Command+Shift+J
  - G4 → F16, G5 → F17, G6 → F18
* Controls M-mode indicator lights on the keyboard (M1 light illuminates by default)
* M1 key works, M2/M3 keys currently don't do anything

In effect, this allows you to use the keyboard in games without any Logitech driver.

### Installation

#### Option 1: macOS App Bundle (Recommended)

Build and install as a proper macOS app that runs silently in the background:

1. Clone this repository:
```bash
git clone https://github.com/Rendann/g710plus.git
cd g710plus
```

2. Build the app bundle:
```bash
./build-app.sh
```

3. Install to Applications folder:
```bash
cp -r g710plus/g710plus/G710Plus.app /Applications/
```

**Advantages:**
- Runs silently without terminal windows
- Proper macOS app bundle with code signing
- Integrates cleanly with Login Items
- Unified logging via Console.app

#### Option 2: Command-Line Executable (Alternative)

1. Clone this repository:
```bash
git clone https://github.com/Rendann/g710plus.git
cd g710plus/g710plus/g710plus
```

2. Build the executable:
```bash
swiftc -o g710plus Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation
```

3. Install to a permanent location (e.g., `/usr/local/bin/`):
```bash
sudo cp g710plus /usr/local/bin/g710plus
```

**Note:** Command-line version shows terminal window when used as login item.

### First Run and Permissions

#### Testing the App Bundle
Open the app to test functionality:
```bash
open /Applications/G710Plus.app
```

#### Testing the Command-Line Version
```bash
/usr/local/bin/g710plus --verbose
```

#### Required Permissions (TCC)
On first run, macOS will prompt for security permissions:

1. **Input Monitoring Permission**: Required to detect G-key presses
   - Location: System Settings > Privacy & Security > Input Monitoring
   - Enable: G710Plus (for app bundle) or g710plus (for command-line)

2. **Accessibility Permission**: May be prompted if needed for key injection
   - Location: System Settings > Privacy & Security > Accessibility
   - Enable: G710Plus when prompted

**Important:** Restart the app after granting permissions for them to take effect.

### Configuration

G-key shortcuts are fully customizable via JSON configuration files. Create `~/.g710plus-config.json` to override defaults:

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

**Key Examples:**
- Letters: `"k"` (lowercase only - use `["shift"]` modifier for uppercase)
- Special: `"Space"`, `"Enter"`, `"Tab"`, `"Escape"`, `"Backspace"`
- Function: `"F1"` through `"F18"`
- Arrows: `"ArrowUp"`, `"ArrowDown"`, `"ArrowLeft"`, `"ArrowRight"`
- Punctuation: `";"` (use `["shift"]` for `":"`), `","`, `"."`, `"1"` (use `["shift"]` for `"!"`), etc.

**Supported Modifiers:**
- `"control"` or `"ctrl"` - Control key
- `"command"` or `"cmd"` - Command key (⌘)
- `"shift"` - Shift key
- `"option"` or `"alt"` - Option/Alt key

**Modifier Examples:**
- `{"key": "k", "modifiers": []}` → k
- `{"key": "k", "modifiers": ["shift"]}` → K
- `{"key": "k", "modifiers": ["command"]}` → ⌘K
- `{"key": "k", "modifiers": ["control", "shift"]}` → ⌃⇧K

**Note:** Uppercase letters (A-Z) are not allowed in key names. Use lowercase letters with explicit `"shift"` modifier instead.

Restart the app after changing configuration.

### Automatic Startup

#### Option 1: App Bundle (Recommended)
Add G710Plus.app to Login Items for clean startup without terminal windows:

1. **Open System Settings** (or System Preferences on older macOS)
2. **Go to General > Login Items** (or Users & Groups > Login Items)
3. **Click the + button** to add a new login item
4. **Navigate to and select:** `/Applications/G710Plus.app`
5. **Make sure it's enabled** (checkbox checked)

The app will start automatically and run silently in the background.

#### Option 2: Command-Line Version
For the command-line executable:

1. Follow the same steps as above but select: `/usr/local/bin/g710plus`
2. **Note:** This will show a terminal window on login

**Alternative command-line method:**
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/G710Plus.app", hidden:false}'
```

**Why Login Items?** Modern macOS security restricts Launch Agents from accessing HID devices during boot. Login Items run with full user privileges and work reliably.

### Troubleshooting

#### G-keys Output Numbers Instead of Function Keys
- **Check if utility is running**: Look for G710Plus in Activity Monitor
- **Verify TCC permissions**: Input Monitoring must be enabled in System Settings
- **Restart after permission grant**: Quit and relaunch the app
- **Test manually**: `open /Applications/G710Plus.app` (for app bundle) or `/usr/local/bin/g710plus --verbose` (for command-line)

#### No G-key Response At All
- **Check Login Items**: Ensure G710Plus.app is in Login Items and enabled
- **Verify TCC permissions**: Both Input Monitoring and Accessibility (if prompted) must be granted
- **Rebuild and re-authorize**: Code signing issues may require TCC re-authorization

#### Viewing Diagnostic Logs
**Console.app Method:**
1. Open Console.app (Applications > Utilities)
2. Filter by process: "G710Plus" or "g710plus"
3. Use predicate: `subsystem == "com.halo.g710plus"`

**Command Line Method:**
```bash
log stream --predicate 'subsystem == "com.halo.g710plus"' --info --debug
```

**Note:** Debug logs may show "Control transfer failed: -536850432" during startup. This is expected and does not affect functionality.

#### When Working Properly
- M1 light should be illuminated on the keyboard
- G-keys trigger configured shortcuts (default: G1-G3→Control+Command+Shift+L/K/J, G4-G6→F16-F18)
- Keys send configured outputs instead of numbers 1-6
- No terminal windows visible (for app bundle)
- Logs show "G710+ keyboard connected" in Console.app

### Limitations

* There is no key-repeat. You press a G key once and it triggers once.

### Credits

* [K900 libusb python script](https://github.com/K900/g710)
* [Eric Betts' KuandoSwift](https://github.com/bettse/KuandoSwift)

### License

Copyright (c) 2016 halo, MIT License

See each respective file or LICENSE.md for more details.
