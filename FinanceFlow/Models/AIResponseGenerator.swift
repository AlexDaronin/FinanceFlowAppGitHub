//
//  AIResponseGenerator.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

enum AIResponseGenerator {
    static func answer(for question: String, currencyCode: String = "USD") -> String {
        if question.localizedCaseInsensitiveContains("spend") {
            return "You spent more on eating out this week. Maybe limit cafés to 2 visits and move savings to your travel fund."
        } else if question.localizedCaseInsensitiveContains("save") {
            return "Try auto-saving 10% of each income into your Savings account. It would add about \(currencyString(325, code: currencyCode)) this month."
        } else if question.localizedCaseInsensitiveContains("debt") {
            return "Your debt payments are on track. Paying an extra \(currencyString(50, code: currencyCode)) removes a month from your schedule."
        } else {
            return "Keep expenses under \(currencyString(3000, code: currencyCode)) to stay within your planned budget. Need projections for next month?"
        }
    }
}

