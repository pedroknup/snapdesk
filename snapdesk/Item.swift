//
//  Item.swift
//  snapdesk
//
//  Created by Pedro Knup on 19/04/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
