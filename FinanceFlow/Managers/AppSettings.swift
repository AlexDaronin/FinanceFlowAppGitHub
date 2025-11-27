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
    private let languageKey = "appLanguage"
    private let themeKey = "appTheme"
    private let startDayKey = "startDay"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let includeCashInTotalsKey = "includeCashInTotals"
    private let subscriptionAlertsKey = "subscriptionAlerts"
    private let premiumEnabledKey = "premiumEnabled"
    private let categoriesKey = "savedCategories"
    
    @Published var currency: String {
        didSet {
            UserDefaults.standard.set(currency, forKey: currencyKey)
        }
    }
    
    @Published var theme: ThemeOption {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        }
    }
    
    @Published var startDay: Int {
        didSet {
            UserDefaults.standard.set(startDay, forKey: startDayKey)
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)
        }
    }
    
    @Published var includeCashInTotals: Bool {
        didSet {
            UserDefaults.standard.set(includeCashInTotals, forKey: includeCashInTotalsKey)
        }
    }
    
    @Published var subscriptionAlerts: Bool {
        didSet {
            UserDefaults.standard.set(subscriptionAlerts, forKey: subscriptionAlertsKey)
        }
    }
    
    @Published var premiumEnabled: Bool {
        didSet {
            UserDefaults.standard.set(premiumEnabled, forKey: premiumEnabledKey)
        }
    }
    
    @Published var categories: [Category] {
        didSet {
            saveCategories()
        }
    }
    
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
        
        // Load theme
        if let savedThemeRaw = UserDefaults.standard.string(forKey: themeKey),
           let savedTheme = ThemeOption(rawValue: savedThemeRaw) {
            _theme = Published(initialValue: savedTheme)
        } else {
            _theme = Published(initialValue: .system)
        }
        
        // Load startDay
        let savedStartDay = UserDefaults.standard.integer(forKey: startDayKey)
        _startDay = Published(initialValue: savedStartDay > 0 ? savedStartDay : 1)
        
        // Load boolean settings
        _notificationsEnabled = Published(initialValue: UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? true)
        _includeCashInTotals = Published(initialValue: UserDefaults.standard.object(forKey: includeCashInTotalsKey) as? Bool ?? true)
        _subscriptionAlerts = Published(initialValue: UserDefaults.standard.object(forKey: subscriptionAlertsKey) as? Bool ?? true)
        _premiumEnabled = Published(initialValue: UserDefaults.standard.object(forKey: premiumEnabledKey) as? Bool ?? false)
        
        // Load categories
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data),
           !decoded.isEmpty {
            _categories = Published(initialValue: decoded)
        } else {
            // Initialize with default categories only on first launch
            _categories = Published(initialValue: Category.defaultCategories)
            saveCategories()
        }
    }
    
    private func saveCategories() {
        // Debug: Print what we're saving
        print("💾 AppSettings: Saving \(categories.count) categories to UserDefaults")
        for cat in categories {
            print("  - \(cat.name): \(cat.subcategories.count) subcategories")
            for subcat in cat.subcategories {
                print("    • \(subcat.name)")
            }
        }
        
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            UserDefaults.standard.synchronize() // Force immediate write
            print("  ✅ Categories saved successfully")
        } else {
            print("  ❌ ERROR: Failed to encode categories")
        }
    }
}

