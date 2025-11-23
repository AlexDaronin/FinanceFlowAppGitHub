//
//  Contact.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct Contact: Identifiable, Codable {
    let id: UUID
    var name: String
    var avatarColor: String // Store color name for persistence
    
    init(id: UUID = UUID(), name: String, avatarColor: String = "blue") {
        self.id = id
        self.name = name
        self.avatarColor = avatarColor
    }
    
    // Computed property for SwiftUI Color
    var color: Color {
        switch avatarColor {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        case "mint": return .mint
        default: return .blue
        }
    }
    
    // Generate initials for avatar
    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[components.count - 1].prefix(1))
            return (first + last).uppercased()
        } else if let first = components.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
    
    // Generate consistent color based on name
    static func generateColor(for name: String) -> String {
        let hash = name.hashValue
        let colors = ["blue", "purple", "pink", "orange", "indigo", "teal", "cyan", "mint"]
        return colors[abs(hash) % colors.count]
    }
    
    // Calculate net balance from transactions (excluding settled transactions)
    func netBalance(from transactions: [DebtTransaction]) -> Double {
        transactions
            .filter { $0.contactId == id && !$0.isSettled } // Only count active (non-settled) transactions
            .reduce(0) { total, transaction in
                switch transaction.type {
                case .lent: // They owe me (positive)
                    return total + transaction.amount
                case .borrowed: // I owe them (negative)
                    return total - transaction.amount
                }
            }
    }
    
    static let sample: [Contact] = [
        Contact(name: "John Smith", avatarColor: "blue"),
        Contact(name: "Sarah Johnson", avatarColor: "purple"),
        Contact(name: "Mike Wilson", avatarColor: "pink"),
        Contact(name: "Emma Davis", avatarColor: "orange")
    ]
}

// DebtTransactionType and DebtTransaction are defined in DebtTransaction.swift
