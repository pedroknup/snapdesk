# Claude Code Guidelines for SnapDesk

## File Management Rules

**DO NOT** create or delete any files in this project.

- If you need a new file to be created, mention it in comments and I will manually create it
- If you need a file to be deleted, mention it in comments and I will manually handle it
- Only edit existing files that are already present in the project

## Project Context

This is a macOS window manager application built with Swift. The main components include:

- **SimpleWindowManager**: Main window management logic with cycling and app launching
- **WindowSet**: Container for windows with layout-based expansion (wide, tall, fullscreen, floating)
- **WorkspaceModel**: Screen and window hierarchy management
- **AX+Windows**: Accessibility API utilities for window manipulation

## Project Structure

```
snapdesk/
├── main.swift                              # App entry point
├── snapdeskApp.swift                       # SwiftUI app definition
├── Item.swift                              # Data models
├── ShortcutRecorderView.swift             # Legacy shortcut UI
├── ShortcutsTabView.swift                 # Legacy shortcuts tab
│
├── Sources/
│   ├── Categories/
│   │   └── NSRunningApplication+Manageable.swift  # App manageability extensions
│   │
│   ├── Managers/                          # Core management systems
│   │   ├── AX+Windows.swift              # Accessibility window operations
│   │   ├── AppCacheManager.swift         # App metadata caching
│   │   ├── FocusFollowMouseManager.swift # Mouse-based focus management
│   │   ├── FocusTransitionCoordinator.swift # Focus transition handling
│   │   ├── LogManager.swift              # Logging system
│   │   ├── ScreenManager.swift           # Screen management
│   │   ├── Screens.swift                 # Screen utilities
│   │   ├── WindowManager.swift           # Window management interface
│   │   ├── WindowTransitionCoordinator.swift # Window transition handling
│   │   ├── Windows.swift                 # Window utilities
│   │   └── Models/                       # Manager-specific models (legacy)
│   │
│   ├── Models/                           # Core data models
│   │   ├── Application.swift             # App representation
│   │   ├── ApplicationEventHandler.swift # App event handling
│   │   ├── ApplicationObservation.swift  # App observation
│   │   ├── CGInfo.swift                  # Core Graphics info
│   │   ├── Change.swift                  # Change tracking
│   │   ├── MouseState.swift              # Mouse state tracking
│   │   ├── PreferencesViewModel.swift    # Settings view model
│   │   ├── Reliable.swift                # Reliability utilities
│   │   ├── Screen.swift                  # Screen representation
│   │   ├── ScreenWorkspace.swift         # Screen workspace model
│   │   ├── Space.swift                   # Space/desktop model
│   │   ├── Window.swift                  # Window representation
│   │   ├── WindowInformation.swift       # Window metadata
│   │   ├── WindowSet.swift               # **Window layout container**
│   │   └── WorkspaceModel.swift          # **Screen hierarchy model**
│   │
│   ├── Preferences/
│   │   └── UserConfiguration.swift       # User settings management
│   │
│   ├── Services/                         # Application services
│   │   ├── ConfigurationManager.swift    # Configuration management
│   │   ├── HotkeyManager.swift          # Hotkey handling
│   │   ├── SettingsWindowController.swift # Settings window
│   │   └── SimpleWindowManager.swift     # **Main window manager**
│   │
│   ├── Utils/                           # Utilities
│   │   ├── DebugLogViewer.swift         # Debug log viewer
│   │   ├── FloatingWindowHelper.swift   # Floating notifications
│   │   └── ScanWindows.swift            # Window discovery
│   │
│   └── VIews/                           # User interface
│       ├── AboutTabView.swift           # About tab
│       ├── PreferencesView.swift        # Main preferences view
│       ├── SettingsTabView.swift        # Settings tab
│       ├── ShortcutRecorder.swift       # Shortcut recording
│       ├── ShortcutsTabView.swift       # Shortcuts tab
│       └── WindowDebugTest.swift        # Window debugging UI
│
└── Assets.xcassets/                     # App resources
    ├── AccentColor.colorset
    ├── AppIcon.appiconset
    ├── snapdesk-logo.imageset
    └── snapdesk-status-bar-icon.imageset
```

## Current Features

- Window tracking with automatic observers for app launch/termination
- **Per-app cycling**: Repeatedly invoking the same app shortcut cycles through that app’s windows
- **Split layout preservation**: If a window is in a split layout with another window, that split configuration **must remain unchanged** when any of its windows are focused again (via cycling or other focus actions)
- Layout-based window expansion: Windows automatically arrange according to their `WindowSet` layout
- Screen-aware: Each `WindowSet` knows which screen it belongs to

## Behavioral Contracts (Important)

Treat these rules as invariants for cycling, focus, and layout behavior.

### App Cycling
- Cycling is triggered by pressing the **same shortcut** for the **same app** repeatedly.
- Cycling iterates through the app’s windows **on the active screen/workspace** in a stable order (MRU or deterministic WindowSet order).
- Cycling **does not** modify any `WindowSet` layout or pane sizes—it only changes focus.

### Split Layout Preservation
- If two (or more) windows share a split layout inside a `WindowSet` (e.g., wide/tall two-pane arrangement), that arrangement **must persist** when:
  - Focusing any window in the split via cycling
  - Refocusing the app from another app
  - Expanding/bringing the app forward within the same `WindowSet`
- Focusing a window inside a split **must not**:
  - Resize or move either split participant
  - Collapse the split into fullscreen
  - Detach a window from its `WindowSet`

### WindowSet & Expansion
- All `WindowSet`s are created with **individual** windows (not grouped stacks) to enable proper cycling.
- Expansion/reflow is allowed when **membership or layout type changes** (e.g., a new window enters the set, layout switches to fullscreen), but **not** on mere focus changes within an existing split.
- `WindowSet.layout ∈ { wide, tall, fullscreen, floating }`. Split preservation applies to `wide` and `tall` configurations.

### Screen Awareness
- `WorkspaceModel` maintains the **screen → spaces → WindowSets → windows** hierarchy.
- Cycling and focus target the `WindowSet` on the **active screen** unless explicitly moved.

## Implementation Notes

- Use `NSWorkspace` notifications to track app lifecycle (launch/terminate/activate) and maintain per-app window lists.
- Use existing `AX+Windows` helpers to focus and bring windows to front **without** reflowing layout.
- Maintain a per-app, per-screen ordering (MRU or deterministic index) for cycling and update it when a window receives focus.
- When cycling:
  1. Resolve the target app’s windows on the active screen.
  2. Select the next window in order.
  3. **Focus via AX** without modifying `WindowSet.layout` or pane sizes.

## Development Notes

- All `WindowSet`s are created with individual windows (not grouped) to enable proper cycling
- Window expansion happens automatically when focusing apps, but must **respect split preservation**: pure focus changes inside an existing split must not reflow pane sizes
- The system uses `NSWorkspace` notifications to track app lifecycle events
- Window positioning uses the AX (Accessibility) API through the existing helper functions

---

**Remember:** **NO file creation or deletion** — request these operations via comments instead.

I must manually test it before you commit. Dont ever commit without having me giving you the green light.
