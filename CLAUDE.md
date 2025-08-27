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

## Current Features

- Window tracking with automatic observers for app launch/termination
- App cycling: Multiple invocations of the same app cycle through its windows
- Layout-based window expansion: Windows automatically arrange according to their WindowSet layout
- Screen-aware: Each WindowSet knows which screen it belongs to

## Development Notes

- All WindowSets are created with individual windows (not grouped) to enable proper cycling
- Window expansion happens automatically when focusing apps
- The system uses NSWorkspace notifications to track app lifecycle events
- Window positioning uses the AX (Accessibility) API through the existing helper functions

Remember: **NO file creation or deletion** - request these operations via comments instead.