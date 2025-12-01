//
//  FormatterHelpers.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

func currencyString(_ amount: Double, code: String = "USD") -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? ""
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
