//
//  AppColors.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

// Custom gray-based dark theme colors
extension Color {
    static var customBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Nice gray instead of black
                : UIColor.systemGroupedBackground
        })
    }
    
    static var customCardBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0) // Lighter gray for cards
                : UIColor.secondarySystemGroupedBackground
        })
    }
    
    static var customSecondaryBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.0) // Medium gray
                : UIColor.secondarySystemGroupedBackground
        })
    }
}

