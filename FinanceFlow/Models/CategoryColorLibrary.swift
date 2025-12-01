//
//  CategoryColorLibrary.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct CategoryColorLibrary {
    // Predefined colors matching iOS system colors
    static let availableColors: [(name: String, color: Color)] = [
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("mint", .mint),
        ("teal", .teal),
        ("cyan", .cyan),
        ("blue", .blue),
        ("indigo", .indigo),
        ("purple", .purple),
        ("pink", .pink),
        ("brown", .brown),
        ("gray", .gray)
    ]
    
    static func color(for name: String) -> Color {
        availableColors.first(where: { $0.name == name })?.color ?? .blue
    }
    
    static func colorName(for color: Color) -> String {
        // Simple matching - in a real app you might want more sophisticated matching
        if let match = availableColors.first(where: { $0.color == color }) {
            return match.name
        }
        return "blue"
    }
}



