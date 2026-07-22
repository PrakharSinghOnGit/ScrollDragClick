# ScrollClick 🖱️⚡

**ScrollClick** is a lightweight, background macOS Menu Bar application written in **Swift** that converts mouse scroll wheel events into rapid, customizable mouse clicks. 

Designed specifically for **Minecraft drag-clicking**, PVP, and high CPS (Clicks Per Second) tasks on mice incapable of drag-clicking.

---

## 🌟 Key Features

1. **Background Menu Bar Application** (`LSUIElement`)
   - Runs purely in the macOS status bar without cluttering your Dock.
   - Quick toggle to pause/enable scroll clicking directly from the menu bar.
2. **Target Application Filter** (Imp)
   - Choose between **All Applications** or **Specific Application**.
   - Preset selector for **Minecraft / Java** (`java`, `Minecraft`, `org.lwjgl.glfw`, `Lunar Client`, `Badlion Client`, `Prism Launcher`).
   - Active frontmost app indicator shows real-time `MATCHED` status.
3. **Configurable Click Ratio & Count**
   - **Clicks per Scroll Tick**: 1 scroll tick = 1 click, 2 clicks, 5 clicks, up to 20 clicks!
   - **Scroll Ticks per Click**: 2 scrolls = 1 click, 3 scrolls = 1 click, etc.
   - **Multi-click Delay**: Adjustable millisecond delay between synthetic clicks (0ms - 50ms) to ensure games like Minecraft register every click cleanly.
4. **Scroll Direction Filter**
   - Options: `Both (Up & Down)`, `Scroll Down Only`, or `Scroll Up Only`.
5. **Mouse Button Selection**
   - Map scroll wheel to:
     - **Left Click** (Button 1)
     - **Right Click** (Button 2 - Great for godbridging/fast placement in Minecraft)
     - **Middle Click** (Button 3)
     - **Mouse Button 4**
     - **Mouse Button 5**
6. **Suppress Original Scroll Event**
   - Prevents scroll wheel movements from changing hotbar item slots in Minecraft while clicking!
7. **Interactive Live Click Tester & Stats Counter**
   - Built-in test box in the preferences window lets you hover and scroll to verify your CPS and click output in real time.

---

## 🚀 Building & Running on macOS

### Prerequisites
- macOS 13.0 or newer
- Swift 5.9+ / Xcode Command Line Tools (`swift --version`)

### Quick Build & Package
Run the included build script in terminal:

```bash
chmod +x build.sh
./build.sh
```

This compiles the Swift release executable and packages **`ScrollClick.app`** in your repository folder.

### Launching
```bash
open ScrollClick.app
```

> **Note on Accessibility Permission**:
> On first launch, macOS requires Accessibility access to listen to global HID scroll events and generate mouse clicks. 
> 1. Click **Grant Access** in the popup or open **System Settings → Privacy & Security → Accessibility**.
> 2. Enable **ScrollClick**.

---

## 🐧 Will it work on Linux? (Linux Cross-Platform Explanation)

### **Short Answer:**
The native macOS Swift binary **will not run directly on Linux** because Apple's `CoreGraphics` (`CGEventTap`), `AppKit`, and `SwiftUI` menu bar status items are macOS-only APIs.

However, we have provided a **native Linux script** (`linux/scroll_click_linux.py`) that implements the exact same functionality on Linux using kernel event devices (`evdev` / `uinput`)!

### **Running on Linux:**

```bash
# 1. Install Python dependencies
pip install evdev python-xlib

# 2. Run ScrollClick on Linux (requires root / uinput permissions)
sudo python3 linux/scroll_click_linux.py --target minecraft --clicks-per-scroll 2 --button left
```

#### Linux Command Options:
- `--target`: Window title / class filter (e.g. `minecraft`, `java`)
- `--clicks-per-scroll`: Number of clicks per scroll tick (default: 1)
- `--direction`: `both`, `down`, or `up`
- `--button`: `left`, `right`, `middle`, `button4`, `button5`

---

## 📁 Repository Structure

```
scrollClick/
├── Package.swift                    # Swift Package Manager manifest
├── Info.plist                       # App bundle configuration (LSUIElement = true)
├── build.sh                         # macOS .app bundling script
├── README.md                        # Documentation
├── Sources/ScrollClick/
│   ├── main.swift                   # AppDelegate & App Entry Point
│   ├── Models/
│   │   └── SettingsStore.swift      # App Storage & UserDefaults Configuration
│   ├── Services/
│   │   ├── AccessibilityManager.swift # macOS Accessibility Permission Checker
│   │   ├── AppDetector.swift        # Frontmost app detection & preset matcher
│   │   ├── ScrollTapEngine.swift    # Low-level CGEventTap event interceptor
│   │   └── StatusBarController.swift# Menu Bar Status Item Manager
│   └── Views/
│       ├── SettingsView.swift       # Preferences & Live Test UI
│       └── AppPickerView.swift      # Running App Selector & Minecraft presets
└── linux/
    └── scroll_click_linux.py        # Linux kernel evdev/uinput scroll-click script
```

---

## 🤖 Continuous Integration & GitHub Releases

An automated GitHub Actions workflow is configured in [.github/workflows/release.yml](file:///.github/workflows/release.yml).

### Creating a New GitHub Release
To automatically build `ScrollClick.app`, package it into `ScrollClick-macOS.zip`, and attach it to a new GitHub Release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Automated Build Artifacts
Every push to `main` or pull request automatically compiles the project on a native macOS GitHub runner and uploads `ScrollClick-macOS.zip` as a workflow artifact.

---

## 📄 License
MIT License
