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
    private let currencyKey = "mainCurrency"
    
    @Published var currency: String {
        didSet {
            UserDefaults.standard.set(currency, forKey: currencyKey)
        }
    }
    
    @Published var theme: ThemeOption = .system
    @Published var startDay: Int = 1
    @Published var notificationsEnabled: Bool = true
    @Published var includeCashInTotals: Bool = true
    @Published var subscriptionAlerts: Bool = true
    @Published var premiumEnabled: Bool = false
    @Published var categories: [Category] = Category.defaultCategories
    
    private let languageKey = "appLanguage"
    
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: languageKey)
        }
    }
    
    var locale: Locale {
        appLanguage.locale
    }
    
    init() {
        // Load currency from UserDefaults or use default
        if let savedCurrency = UserDefaults.standard.string(forKey: currencyKey) {
            _currency = Published(initialValue: savedCurrency)
        } else {
            _currency = Published(initialValue: "USD")
        }
        
        // Load language from UserDefaults or use default
        if let savedLanguageCode = UserDefaults.standard.string(forKey: languageKey),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            _appLanguage = Published(initialValue: savedLanguage)
        } else {
            _appLanguage = Published(initialValue: .default)
        }
        
        // Initialize with default categories if empty
        if categories.isEmpty {
            categories = Category.defaultCategories
        }
    }
}

