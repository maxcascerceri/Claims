//
//  Design.swift
//  Claims
//
//  Shared design tokens for consistent UI.
//

import SwiftUI

enum Asset {
    /// Single accent for amounts, actions, progress, and key badges.
    static let accentGreen = Color(red: 0.2, green: 0.72, blue: 0.45)
    /// Yellow for "Proof required" badge.
    static let proofRequiredYellow = Color(red: 0.9, green: 0.65, blue: 0.1)
    /// Darker gray for titles (slightly darker than system darkGray).
    static let titleGray = Color(white: 0.22)
    /// Darker gray for body/secondary text.
    static let bodyGray = Color(white: 0.38)
}
