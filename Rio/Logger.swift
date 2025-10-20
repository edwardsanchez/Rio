//
//  Logger.swift
//  Rio
//
//  Created on 2025-09-28.
//

import OSLog

extension Logger {
    /// The subsystem identifier for the Rio app
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.rio.app"

    /// Logger for CursiveLetter component - handles SVG loading, path extraction, and letter initialization
    static let cursiveLetter = Logger(subsystem: subsystem, category: "Cursive Letter")

    /// Logger for AnimatedCursiveText component - handles text animation, trim calculations, and offset tracking
    static let animatedCursiveText = Logger(subsystem: subsystem, category: "Animated Cursive Text")

    static let message = Logger(subsystem: subsystem, category: "Message")
}
