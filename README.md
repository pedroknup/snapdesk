# SnapDesk

<div align="center">
  <img src="Assets.xcassets/snapdesk-logo.imageset/snapdesk-logo.png" alt="SnapDesk Logo" width="128" height="128">
  <br/>
  <strong>Effortless window management for macOS power users</strong>
  <br/><br/>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
  
</div>

SnapDesk transforms your macOS experience with intelligent window management that actually understands how you work. No more manually dragging windows around—just press a key and watch your workspace organize itself.

---

## ✨ What Makes SnapDesk Special?

### 🎯 **Smart App Cycling**
Press the same shortcut repeatedly to cycle through all windows of an app. Working on multiple documents in Pages? Hit your Pages shortcut to jump between them instantly.

### 📐 **Intelligent Layouts**
Windows automatically arrange themselves in clean, productive layouts:
- **Wide**: Perfect for side-by-side work
- **Tall**: Great for code and documents  
- **Fullscreen**: Distraction-free focus mode
- **Floating**: For those special windows that need to stay on top

### 🖥️ **Multi-Monitor Magic**
Each screen gets its own workspace. Throw windows between monitors with a single keystroke, and SnapDesk keeps everything organized exactly where you want it.

### 🔄 **Preserves Your Flow**
Working in a split layout? SnapDesk remembers your arrangement. When you cycle between windows or refocus an app, your carefully crafted layout stays exactly as you left it.

### ⚡ **Zero Learning Curve**  
Just assign keyboard shortcuts to your favorite apps and start using them. SnapDesk handles the complex window management behind the scenes.

---

## 🚀 Installation

### Option 1: Homebrew (Recommended)
```bash
# Add the tap
brew tap pedroknup/tap

# Install SnapDesk
brew install --cask snapdesk
```

### Option 2: Direct Download
1. Download the latest release from [GitHub Releases](https://github.com/pedroknup/snapdesk/releases)
2. Unzip and drag SnapDesk.app to your Applications folder
3. Launch SnapDesk and grant accessibility permissions when prompted

### Option 3: Build from Source
```bash
git clone https://github.com/pedroknup/snapdesk.git
cd snapdesk
open snapdesk.xcodeproj
```
Build and run in Xcode, or use `swift build -c release` from the command line.

**System Requirements:** macOS 13.0 (Ventura) or later

---

## 🎮 Getting Started

### First Launch
1. **Launch SnapDesk** from your Applications folder
2. **Grant Accessibility Permissions** when macOS prompts you (this is required for window management)
3. **Open Preferences** from the menu bar icon to configure your shortcuts
4. **Start managing windows** with your configured hotkeys!

### Essential Shortcuts to Set Up
Here are the shortcuts that will transform your workflow:

**App Focus Shortcuts** - Assign each to your most-used apps:
- `⌘ + 1` → Focus your browser (cycling through all browser windows)
- `⌘ + 2` → Focus your code editor  
- `⌘ + 3` → Focus your terminal
- `⌘ + 4` → Focus your notes app

**Layout Management:**
- `⌘ + ⌥ + Space` → Toggle between wide/tall layouts
- `⌘ + ⌥ + F` → Expand current layout to screen
- `⌘ + ⌥ + ↑/↓` → Adjust main panel size

**Window Positioning:**
- `⌘ + ⌥ + ←/→` → Position single window left/right
- `⌘ + ⌥ + T` → Throw window to next monitor

---

## 🛠️ Key Features Explained

### Per-App Window Cycling
Unlike traditional window managers that treat all windows the same, SnapDesk groups windows by application. This means:

- **First press** of your Safari shortcut focuses Safari
- **Second press** cycles to the next Safari window  
- **Third press** cycles to the third Safari window, and so on

This is perfect for developers with multiple editor windows, designers with multiple Figma tabs, or anyone juggling multiple documents.

### Split Layout Preservation  
When you have windows arranged in a split (side-by-side or top-bottom), SnapDesk preserves that arrangement. Cycling between windows in the split won't mess up your carefully crafted layout.

### Screen-Aware Management
Each monitor maintains its own window workspace:
- Windows thrown to a new screen automatically arrange themselves appropriately
- Multi-monitor setups work seamlessly without overlap or confusion
- Screen changes (connecting/disconnecting displays) are handled gracefully

### Automatic Window Tracking
SnapDesk automatically:
- Tracks new windows when apps launch
- Removes windows when apps quit
- Handles app activation and window creation behind the scenes
- Maintains a clean workspace without manual intervention

---

## ⚙️ Configuration

### Layout Preferences
- **Default Layout Mode**: Choose your preferred starting layout (wide, tall, fullscreen, floating)
- **Auto-Expand New Windows**: Automatically fit new windows to your layout
- **Window Margins**: Add padding around windows for a cleaner look

### Behavior Settings
- **Focus Follow Mouse**: Optionally focus windows when hovering
- **Show Layout Indicators**: Visual feedback when changing layouts
- **Throw Notifications**: Confirmations when moving windows between screens

### Hotkey Customization
Set up shortcuts for:
- **App Focus**: Direct shortcuts to launch/focus specific applications
- **Layout Controls**: Toggle layouts, adjust sizes, expand windows
- **Window Actions**: Position, throw between screens, remove from layout
- **Screen Management**: Focus specific monitors, fullscreen toggles

---

## 🔧 Advanced Usage

### Adding Windows to Layouts
Have a window floating by itself? Use the "Add Window to Layout" feature to merge it with your current workspace layout.

### Removing Windows from Layouts  
Need a window to float independently? Remove it from the current layout while keeping the rest of your arrangement intact.

### Custom Window Positioning
For single windows, use the positioning shortcuts to snap them to specific screen areas:
- Left/Right halves for side-by-side reference
- Top/Bottom halves for stacked workflows
- Corners for picture-in-picture style arrangements
- Center for focused work

---

## 🐛 Troubleshooting

### Accessibility Permissions
If SnapDesk isn't working, ensure it has accessibility permissions:
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Find **SnapDesk** in the list and ensure it's enabled
3. If it's not listed, click the **+** button and add SnapDesk manually
4. Restart SnapDesk after granting permissions

### Window Not Responding to Shortcuts
- Some apps (like system dialogs) can't be managed by window managers
- Try focusing the app manually first, then use your shortcut
- Check that your shortcut isn't conflicting with app-specific shortcuts

### Performance on Older Macs
SnapDesk is optimized for modern macOS versions. On older hardware:
- Disable visual indicators if experiencing lag
- Reduce the number of active shortcuts
- Close unnecessary background applications

---

## 🛣️ Roadmap

### Coming Soon
- **Workspace Profiles**: Save and restore different window arrangements
- **Gesture Support**: Multi-touch trackpad gestures for window management
- **Advanced Layouts**: Custom split ratios and complex arrangements
- **App Rules**: Per-application behavior customization

### Future Enhancements
- **Workspace Switching**: Virtual desktop integration
- **Window Previews**: Visual window selection
- **Cloud Sync**: Sync settings across multiple Macs
- **Scripting Support**: Automation and custom workflows

---

## 🤝 Contributing

We welcome contributions! Whether you're:
- 🐛 **Fixing bugs**
- ✨ **Adding features** 
- 📚 **Improving documentation**
- 🎨 **Enhancing UI/UX**

### Getting Started
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes following our coding guidelines
4. Test thoroughly on your system
5. Submit a pull request with a clear description

### Development Setup
```bash
git clone https://github.com/yourusername/snapdesk.git
cd snapdesk
open snapdesk.xcodeproj
```

### Code Guidelines
- Follow existing Swift conventions
- Add comments for complex logic
- Ensure proper error handling
- Test on multiple macOS versions when possible

---

## 💖 Support the Project

If SnapDesk has improved your workflow, consider supporting its development:

<div align="center">
  
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support%20Development-orange?style=for-the-badge&logo=buymeacoffee)](https://buymeacoffee.com/pedroknup)

*Your support helps maintain and improve SnapDesk for everyone!*

</div>

Other ways to help:
- ⭐ **Star this repository** to show your support
- 🐛 **Report bugs** you encounter
- 💡 **Suggest features** you'd like to see
- 📢 **Share SnapDesk** with other power users

---

## 📄 License

SnapDesk is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

SnapDesk is built upon the excellent foundation provided by [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and contributors. We're grateful for their pioneering work in macOS window management.

Special thanks to:
- **Ian Ynda-Hummel** and the **Amethyst team** for the original architectural patterns
- **Early adopters and beta testers** who helped shape SnapDesk
- **The Swift community** for ongoing support and resources
- **All contributors** who make SnapDesk better every day

---

## 📞 Support & Community

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/pedroknup/snapdesk/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/pedroknup/snapdesk/discussions)
- 📧 **Contact**: [pedro@snapdesk.app](mailto:pedro@snapdesk.app)

---

<div align="center">
  
**Made with ❤️ by Pedro Knup**  
*Transforming macOS workflows, one window at a time*

</div>