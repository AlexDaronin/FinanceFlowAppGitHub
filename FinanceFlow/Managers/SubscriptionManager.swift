//
//  SubscriptionManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [PlannedPayment] = []
    
    private let subscriptionsKey = "savedSubscriptions"
    
    init() {
        loadData()
    }
    
    // MARK: - Subscription Management
    
    func addSubscription(_ subscription: PlannedPayment) {
        subscriptions.append(subscription)
        saveData()
    }
    
    func updateSubscription(_ subscription: PlannedPayment) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveData()
        }
    }
    
    func deleteSubscription(_ subscription: PlannedPayment) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveData()
    }
    
    func getSubscription(id: UUID) -> PlannedPayment? {
        subscriptions.first { $0.id == id }
    }
    
    // MARK: - Calculations
    
    /// Calculates total monthly burn (expenses) for the current financial period
    func totalMonthlyBurn(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        return subscriptions
            .filter { subscription in
                subscription.status == .upcoming &&
                !subscription.isIncome &&
                subscription.date >= period.start &&
                subscription.date < period.end
            }
            .map(\.amount)
            .reduce(0, +)
    }
    
    /// Calculates total monthly income for the current financial period
    func totalMonthlyIncome(startDay: Int) -> Double {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        return subscriptions
            .filter { subscription in
                subscription.status == .upcoming &&
                subscription.isIncome &&
                subscription.date >= period.start &&
                subscription.date < period.end
            }
            .map(\.amount)
            .reduce(0, +)
    }
    
    /// Monthly burn rate for the current financial period
    func monthlyBurnRate(startDay: Int) -> Double {
        totalMonthlyBurn(startDay: startDay)
    }
    
    /// Monthly projected income for the current financial period
    func monthlyProjectedIncome(startDay: Int) -> Double {
        totalMonthlyIncome(startDay: startDay)
    }
    
    /// Active subscriptions count within the current financial period
    func activeSubscriptionsCount(startDay: Int) -> Int {
        let period = DateRangeHelper.currentPeriod(for: startDay)
        return subscriptions.filter { subscription in
            subscription.status == .upcoming &&
            subscription.date >= period.start &&
            subscription.date < period.end
        }.count
    }
    
    /// Legacy computed properties for backward compatibility (uses default startDay = 1)
    var totalMonthlyBurn: Double {
        totalMonthlyBurn(startDay: 1)
    }
    
    var totalMonthlyIncome: Double {
        totalMonthlyIncome(startDay: 1)
    }
    
    var monthlyBurnRate: Double {
        totalMonthlyBurn
    }
    
    var monthlyProjectedIncome: Double {
        totalMonthlyIncome
    }
    
    var activeSubscriptionsCount: Int {
        activeSubscriptionsCount(startDay: 1)
    }
    
    func subscriptions(isIncome: Bool) -> [PlannedPayment] {
        subscriptions.filter { $0.isIncome == isIncome }
    }
    
    // Skip a specific date for a repeating payment
    func skipDate(for payment: PlannedPayment, date: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == payment.id }) else {
            return
        }
        
        let calendar = Calendar.current
        let dateToSkip = calendar.startOfDay(for: date)
        
        var existingSkippedDates = payment.skippedDates ?? []
        
        // Check if date is already skipped
        if !existingSkippedDates.contains(where: { calendar.isDate($0, inSameDayAs: dateToSkip) }) {
            existingSkippedDates.append(dateToSkip)
            
            // Update the payment with new skipped dates
            let updatedPayment = PlannedPayment(
                id: payment.id,
                title: payment.title,
                amount: payment.amount,
                date: payment.date,
                status: payment.status,
                accountName: payment.accountName,
                category: payment.category,
                type: payment.type,
                isIncome: payment.isIncome,
                totalLoanAmount: payment.totalLoanAmount,
                remainingBalance: payment.remainingBalance,
                startDate: payment.startDate,
                interestRate: payment.interestRate,
                isRepeating: payment.isRepeating,
                repetitionFrequency: payment.repetitionFrequency,
                repetitionInterval: payment.repetitionInterval,
                selectedWeekdays: payment.selectedWeekdays,
                skippedDates: existingSkippedDates,
                endDate: payment.endDate
            )
            
            subscriptions[index] = updatedPayment
            saveData()
        }
    }
    
    // Set end date for a repeating payment (terminate chain from a specific date forward)
    func setEndDate(for payment: PlannedPayment, endDate: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == payment.id }) else {
            return
        }
        
        let calendar = Calendar.current
        let endDateToSet = calendar.startOfDay(for: endDate)
        
        // Update the payment with end date
        let updatedPayment = PlannedPayment(
            id: payment.id,
            title: payment.title,
            amount: payment.amount,
            date: payment.date,
            status: payment.status,
            accountName: payment.accountName,
            category: payment.category,
            type: payment.type,
            isIncome: payment.isIncome,
            totalLoanAmount: payment.totalLoanAmount,
            remainingBalance: payment.remainingBalance,
            startDate: payment.startDate,
            interestRate: payment.interestRate,
            isRepeating: payment.isRepeating,
            repetitionFrequency: payment.repetitionFrequency,
            repetitionInterval: payment.repetitionInterval,
            selectedWeekdays: payment.selectedWeekdays,
            skippedDates: payment.skippedDates,
            endDate: endDateToSet
        )
        
        subscriptions[index] = updatedPayment
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([PlannedPayment].self, from: data) {
            subscriptions = decoded
        }
    }
}

