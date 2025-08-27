//
//  MouseState.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

enum MouseState<Window: WindowType> {
    case pointing
    case dragging
    case moving(window: Window)
    case resizing(screen: Window.Screen, ratio: CGFloat)
    case doneDragging(Date)
}

protocol MouseStateKeeperDelegate: AnyObject {
    associatedtype Window: WindowType
    func recommendMainPaneRatio(_ ratio: CGFloat)
    func swapDraggedWindowWithDropzone(_ draggedWindow: Window)
}

class MouseStateKeeper<Window: WindowType> {
    weak var delegate: (any MouseStateKeeperDelegate)?
    var state: MouseState<Window> = .pointing
    var lastClick: Date?
    let dragRaceThresholdSeconds: TimeInterval = 0.1
    
    init(delegate: any MouseStateKeeperDelegate) {
        self.delegate = delegate
    }
    
    func handleReflowEvent() {
        // Handle reflow events
    }
    
    func swapDraggedWindowWithDropzone(_ window: Window) {
//        delegate?.swapDraggedWindowWithDropzone(window)
    }
}
