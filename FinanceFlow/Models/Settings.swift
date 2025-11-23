//
//  Settings.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

enum SubscriptionPlan {
    case free
    case premium
    case pro
    
    var title: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "$0"
        case .premium: return "$4.99"
        case .pro: return "$9.99"
        }
    }
}

