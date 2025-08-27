# SnapDesk

**Efficient window management for power users on macOS.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

SnapDesk is a powerful, lightweight window tiling manager for macOS that enables power users to efficiently organize and manage their workspace through keyboard shortcuts and intelligent window arrangements.

## Features

### Core Window Management
- **Automatic Window Tiling**: Intelligent layout-based window expansion (wide, tall, fullscreen, floating)
- **App Cycling**: Multiple invocations of the same app cycle through its windows
- **Multi-Screen Support**: Screen-aware WindowSets for seamless multi-monitor workflows
- **Real-time Window Tracking**: Automatic observers for app launch and termination events

### Advanced Capabilities
- **Focus Follow Mouse**: Optional mouse-based window focusing
- **Floating Window Support**: Dedicated floating window management
- **Customizable Hotkeys**: Fully configurable keyboard shortcuts
- **Debug Tools**: Built-in window debugging and logging utilities

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/pedroknup/snapdesk.git
   cd snapdesk
   ```

2. Open the project in Xcode:
   ```bash
   open snapdesk.xcodeproj
   ```

3. Build and run the project in Xcode, or build from command line:
   ```bash
   swift build -c release
   ```

## Usage

### Getting Started
1. Launch SnapDesk
2. Grant Accessibility permissions when prompted (required for window management)
3. Configure your preferred keyboard shortcuts in Settings
4. Start managing your windows with the configured hotkeys

### Default Features
- Windows are automatically tracked and organized into WindowSets
- Each WindowSet belongs to a specific screen for multi-monitor support
- Window expansion happens automatically when focusing apps
- App cycling allows quick navigation between windows of the same application

## Configuration

SnapDesk uses a YAML-based configuration system. Configuration files are managed through the built-in preferences interface, which provides:

- **Hotkey Management**: Configure custom keyboard shortcuts
- **Window Behavior**: Adjust tiling and floating window settings
- **Screen Settings**: Multi-monitor configuration options
- **Debug Options**: Enable logging and debugging features

## Contributing

We welcome contributions to SnapDesk! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/snapdesk.git
   cd snapdesk
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Make your changes following the existing code style
5. Test thoroughly on your system
6. Commit with clear, descriptive messages
7. Push and create a pull request

### Code Style Guidelines

- Follow Swift conventions and existing code patterns
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure proper error handling
- Test on multiple macOS versions when possible

### Reporting Issues

Before reporting an issue:
1. Check existing issues to avoid duplicates
2. Test with the latest version
3. Include system information (macOS version, hardware)
4. Provide clear reproduction steps
5. Include relevant log output when applicable

## Architecture

SnapDesk is built with a modular architecture:

- **SimpleWindowManager**: Main window management logic with cycling and app launching
- **WindowSet**: Container for windows with layout-based expansion capabilities
- **WorkspaceModel**: Screen and window hierarchy management
- **AX+Windows**: Accessibility API utilities for window manipulation
- **HotkeyManager**: Keyboard shortcut handling and registration

## License

SnapDesk is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

SnapDesk is heavily inspired by and built upon code from [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and contributors. We extend our sincere gratitude to the Amethyst project for pioneering tiling window management on macOS and providing a solid foundation for this work.

Special thanks to:
- **Ian Ynda-Hummel** and the **Amethyst contributors** for the original implementation and architectural patterns
- The Swift and macOS developer communities for their ongoing support and resources
- All beta testers and contributors who help make SnapDesk better

## Support

- **Documentation**: Check this README and in-app help
- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/pedroknup/snapdesk/issues)
- **Discussions**: Join conversations on [GitHub Discussions](https://github.com/pedroknup/snapdesk/discussions)

---

**Author**: Pedro Knup  
**Version**: 0.0.1 (beta)  
**Website**: https://github.com/pedroknup/snapdesk