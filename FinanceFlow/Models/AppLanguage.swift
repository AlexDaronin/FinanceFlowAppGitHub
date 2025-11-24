//
//  AppLanguage.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .chinese: return "简体中文"
        }
    }
    
    var locale: Locale {
        Locale(identifier: rawValue)
    }
    
    static var `default`: AppLanguage {
        .english
    }
}

