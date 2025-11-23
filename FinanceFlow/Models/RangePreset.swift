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
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .year: return "12M"
        }
    }
}

