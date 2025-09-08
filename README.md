# SnapDesk

<div align="center">
  <img src="Assets.xcassets/snapdesk-logo.imageset/snapdesk-logo.png" alt="SnapDesk Logo" width="128" height="128">
  <br/>
  <strong>Keyboard-driven window management for macOS</strong>
  <br/><br/>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
  
</div>

SnapDesk is a keyboard-driven window manager for macOS. Assign shortcuts to applications and organize windows into layouts without manual dragging.

## Features

### Window Management
- Per-application window cycling with keyboard shortcuts
- Automatic window organization into layouts (wide, tall, fullscreen, floating)
- Multi-monitor support with per-screen workspaces
- Split layout preservation during window cycling

### Layouts
- **Wide**: Horizontal window arrangement
- **Tall**: Vertical window arrangement  
- **Fullscreen**: Single window fills screen
- **Floating**: Windows maintain current positions

### Controls
- App focus shortcuts for direct application access
- Layout toggle and size adjustment shortcuts
- Window positioning to screen edges
- Throw windows between monitors

## Installation

### Homebrew
```bash
brew tap pedroknup/tap
brew install --cask snapdesk
```

### Build from Source
```bash
git clone https://github.com/pedroknup/snapdesk.git
cd snapdesk
open snapdesk.xcodeproj
```

**Requirements:** macOS 13.0+ with Accessibility permissions (no SIP disabling required)

## Configuration

1. Launch SnapDesk and grant Accessibility permissions
2. Configure keyboard shortcuts in Preferences
3. Assign shortcuts to applications for focus and cycling
4. Set layout control shortcuts for window arrangement

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow existing Swift conventions
4. Test on macOS 13.0+
5. Submit pull request

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Built upon [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and contributors. The foundational window management architecture and patterns are derived from their excellent work.

## Support

- Bug Reports: [GitHub Issues](https://github.com/pedroknup/snapdesk/issues)
- Discussions: [GitHub Discussions](https://github.com/pedroknup/snapdesk/discussions)