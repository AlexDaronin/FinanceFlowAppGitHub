//
//  CreditManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class CreditManager: ObservableObject {
    @Published var credits: [Credit] = []
    
    static let shared = CreditManager()
    
    private let creditsKey = "savedCredits"
    
    private init() {
        loadData()
        if credits.isEmpty {
            // Initialize with sample data if empty
            credits = Credit.sample
            saveData()
        }
    }
    
    // MARK: - Credit Management
    
    func addCredit(_ credit: Credit) {
        credits.append(credit)
        saveData()
    }
    
    func updateCredit(_ credit: Credit) {
        if let index = credits.firstIndex(where: { $0.id == credit.id }) {
            credits[index] = credit
            saveData()
        }
    }
    
    func deleteCredit(_ credit: Credit) {
        credits.removeAll { $0.id == credit.id }
        saveData()
    }
    
    func getCredit(id: UUID) -> Credit? {
        credits.first { $0.id == id }
    }
    
    // MARK: - Calculations
    
    var totalRemaining: Double {
        credits.map(\.remaining).reduce(0, +)
    }
    
    var activeCreditsCount: Int {
        credits.filter { $0.remaining > 0 }.count
    }
    
    var nextDueDate: Date? {
        credits
            .filter { $0.remaining > 0 }
            .map(\.dueDate)
            .min()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(credits) {
            UserDefaults.standard.set(encoded, forKey: creditsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: creditsKey),
           let decoded = try? JSONDecoder().decode([Credit].self, from: data) {
            credits = decoded
        }
    }
}
