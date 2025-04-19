//
//  main.swift
//  snapdesk
//
//  Created by Pedro Knup on 18/04/2025.
//

import Cocoa

_ = NSApplication.shared
let delegate = SnapdeskApp()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)


