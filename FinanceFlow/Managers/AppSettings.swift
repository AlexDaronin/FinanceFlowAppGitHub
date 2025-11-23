//
//  AppSettings.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    @Published var currency: String = "USD"
    @Published var theme: ThemeOption = .system
    @Published var startDay: Int = 1
    @Published var language: String = "English"
    @Published var notificationsEnabled: Bool = true
    @Published var includeCashInTotals: Bool = true
    @Published var subscriptionAlerts: Bool = true
    @Published var premiumEnabled: Bool = false
    @Published var categories: [Category] = Category.defaultCategories
    
    init() {
        // Initialize with default categories if empty
        if categories.isEmpty {
            categories = Category.defaultCategories
        }
    }
}

