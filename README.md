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
* Maps G-keys to F13-F18 function keys with hold/release functionality:
  - G1 → F13, G2 → F14, G3 → F15, G4 → F16, G5 → F17, G6 → F18
* Controls M-mode indicator lights on the keyboard (M1 light illuminates by default)
* M1 key works, M2/M3 keys currently don't do anything

In effect, this allows you to use the keyboard in games without any Logitech driver.

### Installation

#### Option 1: Build from Source (Recommended)

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

**Note:** You can install it anywhere permanent - `/usr/local/bin/` is just a common choice.

#### Option 2: Download Pre-built Binary

```bash
# Download and install pre-built binary
sudo bash -c "curl -L https://github.com/Rendann/g710plus/releases/latest/download/g710plus > /usr/local/bin/g710plus"
sudo chmod +x /usr/local/bin/g710plus
```

### First Run

Test the utility manually first:

```bash
/usr/local/bin/g710plus --verbose
```

**Important:** On first run, macOS may prompt you to grant permissions for the utility to communicate with your keyboard.

### Automatic Startup

To have the utility start automatically when you log in:

1. **Open System Settings** (or System Preferences on older macOS)
2. **Go to General > Login Items** (or Users & Groups > Login Items)
3. **Click the + button** to add a new login item
4. **Navigate to and select:** `/usr/local/bin/g710plus`
5. **Make sure it's enabled** (checkbox checked)

**Alternative command-line method:**
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/usr/local/bin/g710plus", hidden:false}'
```

**Why Login Items instead of Launch Agents?** Modern macOS security (especially Sequoia) restricts Launch Agents from accessing HID devices during boot. Login Items run with full user privileges and work reliably.

### Troubleshooting

**If G-keys output numbers instead of working:**
- The utility is not running - check Login Items or run manually with `--verbose`

**When working properly:**
- M1 light should be illuminated
- G1-G6 keys work as F13-F18 (not numbers 1-6)

### Limitations

* There is no key-repeat. You press a G key once and it triggers once.

### Credits

* [K900 libusb python script](https://github.com/K900/g710)
* [Eric Betts' KuandoSwift](https://github.com/bettse/KuandoSwift)

### License

Copyright (c) 2016 halo, MIT License

See each respective file or LICENSE.md for more details.
