# Refactoring Handover Document
**Session Date:** 2025-11-21  
**Branch:** `refactor/extract-services`  
**Goal:** Reduce SimpleWindowManager from 1184 lines to ~400 lines  

---

## ✅ COMPLETED WORK

### Phase 1-3: Foundation & Organization (Commits: 945f206, 58d7830, b08255b, e4dd06b, 1a1234c, 2f74471)

**Created Utility Classes:**
1. `WorkspaceHelpers.swift` - moveCursorToCenter, findWindowSetContaining
2. `ConfigurationHelpers.swift` - getDefaultLayoutMode, shouldAutoExpandNewWindows  
3. `NotificationPositionCalculator.swift` - Window position calculation
4. `NotificationWindowState.swift` - Notification state management
5. `ScreenConfigurationHandler.swift` - Screen configuration change handling (~165 lines)

**Enhanced WorkspaceModel:**
- Added query methods: allWindowSets(), allWindows(), windowCount(), windowSetCount()

**Organized Large Files:**
- Added MARK comments with extraction TODOs to FloatingWindowHelper (1509 lines)
- Added MARK comments with extraction TODOs to SimpleWindowManager (1184 lines)

**Code Quality:**
- Removed ~200 lines of duplication
- Inlined unnecessary wrapper methods in SimpleWindowManager
- Added WorkspaceProvider protocol for dependency injection

**Current State:**
- SimpleWindowManager: 1184 → **1061 lines** (-123 lines, -10%)
- FloatingWindowHelper: 1509 → 1465 lines (-44 lines)
- LayoutManager: 653 → 603 lines (-50 lines)
- Build: ✅ PASSING

---

## 🎯 REMAINING WORK TO REACH ~400 LINES

**Target:** Extract ~660 more lines from SimpleWindowManager

### High Priority Extractions (Recommended Order)

#### 1. **Window Reordering Service** (~140 lines)
**Location:** Lines 616-755 (SimpleWindowManager.swift)
**Complexity:** Medium
**Dependencies:** CyclingManager, workspace

**Methods to Extract:**
```swift
// Public API
func moveWindowUpInLayout()
func moveWindowDownInLayout()

// Private implementation
private func moveWindowInLayout(direction: MoveDirection)
private func performWindowCyclingOrderChange(direction: MoveDirection, focusedWindow: AXUIElement)
private func showCyclingOrderFeedback(bundleID: String, appName: String, windowOrder: [CGWindowID], focusedWindowID: CGWindowID)
private func truncateString(_ string: String, maxLength: Int) -> String
```

**Extraction Plan:**
- Create `WindowOrderManager.swift`
- Inject CyclingManager and workspace via protocol
- Methods modify cycling order, show feedback
- SimpleWindowManager keeps thin wrapper methods

**Estimated Impact:** -140 lines

---

#### 2. **Dead Window Cleanup Service** (~70 lines)
**Location:** Lines 759-822 (SimpleWindowManager.swift)
**Complexity:** Low-Medium
**Dependencies:** workspace, CyclingManager

**Methods to Extract:**
```swift
private func removeDeadWindow(_ deadWindow: AXWindow, from windowSet: WindowSet, bundleID: String)
private func focusNextAvailableWindow(for bundleID: String, excluding excludedWindow: AXWindow) async
private func removeEmptyWindowSet(_ windowSet: WindowSet)
```

**Extraction Plan:**
- Create `WindowCleanupService.swift`
- Takes WorkspaceProvider and CyclingManager
- Handles dead window detection, removal, cleanup
- Async method for focusing next available window

**Estimated Impact:** -70 lines

---

#### 3. **Screen Management Service** (~80 lines)
**Location:** Lines 238-314 (SimpleWindowManager.swift)
**Complexity:** Medium
**Dependencies:** workspace, LayoutManager

**Methods to Extract:**
```swift
// Public API
func toggleFullScreen()
func focusScreen(_ screenNumber: Int)
func throwToScreen(_ screenNumber: Int)
func focusScreen(at index: Int)
func throwFrontmostWindow(toScreen index: Int)
```

**Extraction Plan:**
- Create `ScreenNavigationService.swift`
- Inject workspace and LayoutManager
- Screen focus and window throwing logic
- SimpleWindowManager delegates to service

**Estimated Impact:** -80 lines

---

#### 4. **App Focus Logic (Partial)** (~200 lines)
**Location:** Lines 92-205 (SimpleWindowManager.swift)
**Complexity:** High (tightly coupled)
**Dependencies:** CyclingManager, AppLifecycleManager, workspace

**Note:** This is the most complex extraction. The app management section is tightly integrated with cycling, lifecycle, and workspace. 

**Recommended Approach:**
- **DO NOT** extract the entire App Management section initially
- Extract **implementation details** into helper service
- Keep public API (`focusApp`, `cycleCurrentAppBackward`) in SimpleWindowManager
- Create `AppFocusCoordinator.swift` for the complex logic

**Methods to Consider:**
```swift
// Keep in SimpleWindowManager (public API)
func focusApp(_ bundleID: String) async
func cycleCurrentAppBackward() async

// Extract to AppFocusCoordinator
private func focusAppBackward(_ bundleID: String) async -> implementation details
private func performFocusWithRetry(...) -> logic
private func handleFailedFocus(...) -> error handling
```

**Alternative:** Consider leaving this section for now and extract smaller pieces first to reach 400 lines without touching the most complex code.

**Estimated Impact:** ~100-200 lines (if partially extracted)

---

#### 5. **Window Positioning Commands** (~45 lines)
**Location:** Lines 568-614 (SimpleWindowManager.swift)
**Complexity:** Very Low
**Dependencies:** LayoutManager

**Note:** These are already thin wrappers around LayoutManager.positionSingleWindow(). Could be left as-is or inlined completely.

**Methods:**
```swift
func positionWindowLeft()
func positionWindowRight()
func positionWindowTop()
func positionWindowBottom()
func positionWindowTopLeft()
func positionWindowTopRight()
func positionWindowBottomLeft()
func positionWindowBottomRight()
func positionWindowCenter()

private func positionSingleWindow(to position: String)
```

**Recommendation:** Low priority. These are already simple delegates. Focus on larger extractions first.

---

#### 6. **Layout Visualization** (~60 lines)
**Location:** Lines 508-566 (SimpleWindowManager.swift)
**Complexity:** Low
**Dependencies:** None (uses FloatingWindowHelper)

**Methods to Extract:**
```swift
func showLayoutVisualization()
private func showLayoutVisualization(duration: TimeInterval, isAutomatic: Bool)
private func showAutomaticLayoutVisualization()
private func createLayoutVisualization() -> NSAttributedString
```

**Extraction Plan:**
- Create `LayoutVisualizationService.swift`
- Pure presentation logic, no workspace dependencies
- Could be extracted quickly

**Estimated Impact:** -60 lines

---

## 📐 EXTRACTION MATH

| Component | Lines | Running Total |
|-----------|-------|---------------|
| **Current** | 1061 | 1061 |
| - Window Reordering | 140 | 921 |
| - Dead Window Cleanup | 70 | 851 |
| - Screen Management | 80 | 771 |
| - Layout Visualization | 60 | 711 |
| - App Focus (partial) | 150 | 561 |
| **= Remaining Core** | ~561 | **561** |

To reach **~400 lines**, need to extract an additional ~160 lines from:
- Window Positioning wrappers (45 lines) - inline or extract
- Private helper methods
- Additional App Focus logic
- WindowManaging protocol methods that could be simplified

---

## 🛠️ EXTRACTION PATTERN (Reference)

### Standard Service Extraction Steps:

1. **Create Protocol (if needed)**
```swift
protocol WorkspaceProvider: AnyObject {
    var workspace: WorkspaceModel { get set }
}
```

2. **Create Service Class**
```swift
class WindowOrderManager {
    private weak var workspaceProvider: WorkspaceProvider?
    private let cyclingManager: CyclingManager
    
    init(workspaceProvider: WorkspaceProvider, cyclingManager: CyclingManager) {
        self.workspaceProvider = workspaceProvider
        self.cyclingManager = cyclingManager
    }
    
    func moveWindowUp() {
        // Extracted logic here
    }
}
```

3. **Add to SimpleWindowManager**
```swift
class SimpleWindowManager: WindowManaging, WorkspaceProvider {
    // Existing properties...
    private var windowOrderManager: WindowOrderManager!
    
    init() {
        // ... existing init ...
        self.windowOrderManager = WindowOrderManager(
            workspaceProvider: self,
            cyclingManager: cyclingManager
        )
    }
    
    // Thin wrapper
    func moveWindowUpInLayout() {
        windowOrderManager.moveWindowUp()
    }
}
```

4. **Build & Test**
```bash
xcodebuild -project snapdesk.xcodeproj -scheme snapdesk -configuration Debug build
```

5. **Commit**
```bash
git add -A
git commit -m "refactor: extract WindowOrderManager from SimpleWindowManager

- Create WindowOrderManager for window reordering logic
- Extract moveWindowInLayout, performWindowCyclingOrderChange methods
- SimpleWindowManager: 1061 -> 921 lines (-140)
- Improves separation of concerns for window ordering"
```

---

## ⚠️ IMPORTANT NOTES

### WorkspaceModel Mutability
WorkspaceModel is a struct, so mutations require:
1. Get mutable copy: `var workspace = provider.workspace`
2. Modify: `workspace.screens[idx].windowSets.append(...)`
3. Write back: `provider.workspace = workspace`

### Dependencies Pattern
- Use weak references for WorkspaceProvider to avoid retain cycles
- Inject CyclingManager, LayoutManager, etc. via init
- Keep SimpleWindowManager as coordinator that delegates

### Testing Strategy
- Build after each extraction
- No need to manually test behavior until all extractions complete
- User will test on branch before merging

### Files NOT to Create/Delete
Per CLAUDE.md:
- Request new file creation via comments
- User will manually create empty files
- User will add them to Xcode project
- Then populate them with code

---

## 🚀 RECOMMENDED NEXT SESSION STEPS

1. **Start with Window Reordering** (quickest win, -140 lines)
   - Create `WindowOrderManager.swift` (request from user)
   - Extract methods listed above
   - Update SimpleWindowManager to use it

2. **Then Dead Window Cleanup** (-70 lines)
   - Create `WindowCleanupService.swift`
   - Extract cleanup logic
   - Handle async methods properly

3. **Then Screen Management** (-80 lines)
   - Create `ScreenNavigationService.swift`  
   - Extract screen focus/throwing

4. **Check progress** (~711 lines at this point)
   - If close to 400, decide on final extractions
   - If not, tackle Layout Visualization or partial App Focus

5. **Final cleanup**
   - Inline any remaining unnecessary wrappers
   - Simplify WindowManaging protocol implementations if possible
   - Final build verification

**Goal:** SimpleWindowManager at ~400 lines, well-organized, focused on coordination

---

## 📊 CURRENT METRICS

```
SimpleWindowManager: 1061 lines
  - App Management: ~150 lines
  - Screen Management: ~80 lines  
  - WindowManaging methods: ~200 lines
  - Layout Visualization: ~60 lines
  - Window Positioning: ~45 lines
  - Window Reordering: ~140 lines
  - Dead Window Cleanup: ~70 lines
  - Private helpers: ~100 lines
  - Initialization: ~50 lines
  - Refresh/scan: ~60 lines
  - Other: ~106 lines
```

---

## 🔗 USEFUL GREP PATTERNS

```bash
# Find MARK sections
awk '/^    \/\/ MARK:/{print NR": "$0}' SimpleWindowManager.swift

# Count lines in a section (e.g., lines 616-755)
sed -n '616,755p' SimpleWindowManager.swift | wc -l

# Find all public methods
grep -n "^    func " SimpleWindowManager.swift

# Find all private methods
grep -n "^    private func " SimpleWindowManager.swift
```

---

## ✅ SUCCESS CRITERIA

- [ ] SimpleWindowManager is ~400 lines (tolerance: 380-420)
- [ ] Build succeeds with no errors
- [ ] All extracted services follow same pattern (WorkspaceProvider, dependency injection)
- [ ] SimpleWindowManager acts as coordinator, delegates to services
- [ ] Code organization is clear with MARK comments
- [ ] Commit messages follow conventional format

---

**Good luck with the next session! The foundation is solid and the path forward is clear.** 🚀
