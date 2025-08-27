//
//  ScreenManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/23/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol ScreenManagerDelegate: AnyObject {
    associatedtype Window: WindowType
    func applyWindowLimit(forScreenManager screenManager: ScreenManager<Self>, minimizingIn range: (_ windowCount: Int) -> Range<Int>)
    func activeWindowSet(forScreenManager screenManager: ScreenManager<Self>) -> WindowSet<Window>
    func onReflowInitiation()
    func onReflowCompletion()
}

final class ScreenManager<Delegate: ScreenManagerDelegate>: NSObject, Codable {
    typealias Window = Delegate.Window
    typealias Screen = Window.Screen

    enum CodingKeys: String, CodingKey {
        case layoutsBySpaceUUID
    }

    weak var delegate: Delegate?

    private(set) var screen: Screen?
    private(set) var space: Space?

    /// The last window that has been focused on the screen. This value is updated by the notification observations in
    /// `ObserveApplicationNotifications`.
    private(set) var lastFocusedWindow: Window?
    private let userConfiguration: UserConfiguration

    private let reflowOperationDispatchQueue = DispatchQueue(
        label: "ScreenManager.reflowOperationQueue",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    private let reflowOperationQueue = OperationQueue()

//    private var layouts: [Layout<Window>] = []
    private var currentLayoutIndexBySpaceUUID: [String: Int] = [:]
//    private var layoutsBySpaceUUID: [String: [Layout<Window>]] = [:]
    private var currentLayoutIndex: Int = 0
    var previousLayoutKey: String?
    var currentLayout: Layout<Window>? {
        guard !layouts.isEmpty else {
            return nil
        }
        return layouts[currentLayoutIndex]
    }

//    private let layoutNameWindowController: LayoutNameWindowController

    init(screen: Screen, delegate: Delegate, userConfiguration: UserConfiguration) {
        self.screen = screen
        self.delegate = delegate
        self.userConfiguration = userConfiguration

//        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

//        layouts = LayoutType.layoutsWithConfiguration(userConfiguration)

        reflowOperationQueue.underlyingQueue = reflowOperationDispatchQueue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
//        let layoutsBySpaceUUID = try values.decode([String: [[String: Data]]].self, forKey: .layoutsBySpaceUUID)

        self.userConfiguration = UserConfiguration.shared
//        self.layoutsBySpaceUUID = try layoutsBySpaceUUID.mapValues { keyedLayouts -> [Layout<Window>] in
//            return try ScreenManager<Delegate>.decodedLayouts(from: keyedLayouts, userConfiguration: UserConfiguration.shared)
//        }

//        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")
    }


    func updateScreen(to screen: Screen) {
        self.screen = screen
    }

    func updateSpace(to space: Space) {
        if let currentSpace = self.space {
            currentLayoutIndexBySpaceUUID[currentSpace.uuid] = currentLayoutIndex
        }

        defer {
            setNeedsReflow(withWindowChange: .spaceChange)
        }

        self.space = space

        setCurrentLayoutIndex(currentLayoutIndexBySpaceUUID[space.uuid] ?? 0, changingSpace: true)
    }

    func setNeedsReflow(withWindowChange windowChange: Change<Window>) {
        switch windowChange {
        case let .add(window: window):
            lastFocusedWindow = window
        case let .focusChanged(window):
            lastFocusedWindow = window
        case let .remove(window):
            if lastFocusedWindow == window {
                lastFocusedWindow = nil
            }
        case .windowSwap, .applicationActivate, .applicationDeactivate, .spaceChange, .layoutChange, .tabChange, .none, .unknown:
            break
        }

        reflowOperationQueue.cancelAllOperations()

        log.debug("Screen: \(screen?.screenID() ?? "unknown") -- Window Change: \(windowChange)")

        DispatchQueue.main.async {
            self.minimizeWindows()
            self.reflow(windowChange)
        }
    }

    private func minimizeWindows() {
        let mainPaneCount = (currentLayout as? PanedLayout)?.mainPaneCount ?? 0

        guard UserConfiguration.shared.tilingEnabled, let windowLimit = UserConfiguration.shared.windowMaxCount() else {
            return
        }
        let shouldInsertAtFront = UserConfiguration.shared.sendNewWindowsToMainPane()
        delegate?.applyWindowLimit(forScreenManager: self, minimizingIn: { windowCount in

            if windowLimit > windowCount {
                // Not enough windows to minimize.
                return 0 ..< 0
            }
//            if !(currentLayout is PanedLayout) {
//                // Minimize from the back, for layouts like floating/fullscreen.
//                if shouldInsertAtFront {
//                    return windowLimit ..< windowCount
//                } else {
//                    return 0 ..< windowCount - windowLimit
//                }
//            }
            if windowLimit <= mainPaneCount {
                // Don't minimize main panes. This allowing varying main pane count to pin windows.
                guard windowCount >= mainPaneCount else {return 0 ..< 0}
                return mainPaneCount ..< windowCount
            }
            // Minimize the oldest non-main panes.
            if shouldInsertAtFront {
                return windowLimit ..< windowCount
            } else {
                return mainPaneCount ..< windowCount + mainPaneCount - windowLimit
            }
        })
    }

    private func reflow(_ event: Change<Window>) {
        guard let screen = screen else {
            return
        }

        guard userConfiguration.tilingEnabled, space?.type == CGSSpaceTypeUser else {
            return
        }

        guard let windows = delegate?.activeWindowSet(forScreenManager: self) else {
            return
        }

        guard let layout = currentLayout, let frameAssignments = layout.frameAssignments(windows, on: screen) else {
            return
        }

        let mouseFollowsFocus = userConfiguration.mouseFollowsFocus()

        let completeOperation = BlockOperation()

        // The complete operation should execute the completion delegate call
        completeOperation.addExecutionBlock { [unowned completeOperation, weak self] in
            if completeOperation.isCancelled {
                return
            }

            DispatchQueue.main.async {
                self?.delegate?.onReflowCompletion()
                if mouseFollowsFocus {
                    if case .windowSwap(let window, _) = event {
                        window.focus()
                    }
                }

            }
        }

        // The completion should be dependent on all assignments finishing
        frameAssignments.forEach { completeOperation.addDependency($0) }

        // Start the operation
        delegate?.onReflowInitiation()
        reflowOperationQueue.addOperations(frameAssignments, waitUntilFinished: false)
        reflowOperationQueue.addOperation(completeOperation)
    }

//    func updateCurrentLayout(_ updater: (Layout<Window>) -> Void) {
//        guard let layout = currentLayout else {
//            return
//        }
//        updater(layout)
//        setNeedsReflow(withWindowChange: .layoutChange)
//    }
//
//    func cycleLayoutForward() {
//        setCurrentLayoutIndex((currentLayoutIndex + 1) % layouts.count)
//        setNeedsReflow(withWindowChange: .layoutChange)
//    }
//
//    func cycleLayoutBackward() {
//        setCurrentLayoutIndex((currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1)
//        setNeedsReflow(withWindowChange: .layoutChange)
//    }

   
//    func shrinkMainPane() {
//        guard let panedLayout = currentLayout as? PanedLayout else {
//            return
//        }
//        panedLayout.shrinkMainPane()
//    }
//
//    func expandMainPane() {
//        guard let panedLayout = currentLayout as? PanedLayout else {
//            return
//        }
//        panedLayout.expandMainPane()
//    }
//
//    func nextWindowIDCounterClockwise() -> Window.WindowID? {
//        guard let layout = currentLayout as? StatefulLayout else {
//            return nil
//        }
//
//        return layout.nextWindowIDCounterClockwise()
//    }

//    func nextWindowIDClockwise() -> Window.WindowID? {
//        guard let statefulLayout = currentLayout as? StatefulLayout else {
//            return nil
//        }
//
//        return statefulLayout.nextWindowIDClockwise()
//    }

}

extension ScreenManager: Comparable {
    static func < (lhs: ScreenManager<Delegate>, rhs: ScreenManager<Delegate>) -> Bool {
        guard let lhsScreen = lhs.screen, let rhsScreen = rhs.screen else {
            return false
        }

        let originX1 = lhsScreen.frameWithoutDockOrMenu().origin.x
        let originX2 = rhsScreen.frameWithoutDockOrMenu().origin.x

        return originX1 < originX2
    }
}
