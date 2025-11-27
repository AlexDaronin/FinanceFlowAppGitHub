//
//  FormatterHelpers.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

func currencyString(_ value: Double, code: String = "USD") -> String {
    value.formatted(.currency(code: code))
}

func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

func formatDateForCredit(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

/// Normalizes decimal input to accept both dots and commas as decimal separators
/// Converts commas to dots and ensures only one decimal separator exists
func normalizeDecimalInput(_ input: String) -> String {
    // Replace commas with dots
    var normalized = input.replacingOccurrences(of: ",", with: ".")
    
    // Filter to only allow numbers and dots
    normalized = normalized.filter { $0.isNumber || $0 == "." }
    
    // Ensure only one decimal separator
    let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
    if components.count > 2 {
        // Multiple dots found, keep only the first one
        let firstPart = String(components[0])
        let rest = components.dropFirst().joined(separator: "")
        normalized = firstPart + "." + rest
    }
    
    return normalized
}

