//
//  RangePreset.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum RangePreset: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case year
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .threeMonths: return String(localized: "3M", comment: "3 months range")
        case .sixMonths: return String(localized: "6M", comment: "6 months range")
        case .year: return String(localized: "12M", comment: "12 months range")
        }
    }
}

