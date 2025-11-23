//
//  DebtManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class DebtManager: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var transactions: [DebtTransaction] = []
    
    private let contactsKey = "savedContacts"
    private let transactionsKey = "savedDebtTransactions"
    
    init() {
        loadData()
        if contacts.isEmpty {
            // Initialize with sample data if empty
            contacts = Contact.sample
            transactions = DebtTransaction.sample
            saveData()
        }
    }
    
    // MARK: - Contact Management
    
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        saveData()
    }
    
    func updateContact(_ contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            saveData()
        }
    }
    
    func deleteContact(_ contact: Contact) {
        // Delete all associated transactions
        transactions.removeAll { $0.contactId == contact.id }
        contacts.removeAll { $0.id == contact.id }
        saveData()
    }
    
    func getContact(id: UUID) -> Contact? {
        contacts.first { $0.id == id }
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: DebtTransaction) {
        transactions.append(transaction)
        saveData()
    }
    
    func updateTransaction(_ transaction: DebtTransaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            saveData()
        }
    }
    
    func deleteTransaction(_ transaction: DebtTransaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveData()
    }
    
    func getTransactions(for contactId: UUID) -> [DebtTransaction] {
        transactions
            .filter { $0.contactId == contactId }
            .sorted { $0.date > $1.date }
    }
    
    // MARK: - Calculations
    
    func getContactsWithBalance() -> [(contact: Contact, balance: Double, direction: DebtDirection)] {
        contacts.map { contact in
            let balance = contact.netBalance(from: transactions)
            let direction: DebtDirection = balance > 0 ? .owedToMe : .iOwe
            return (contact: contact, balance: abs(balance), direction: direction)
        }
        .filter { $0.balance != 0 } // Only show contacts with non-zero balance (active debts)
    }
    
    func contactsOwedToMe() -> [(contact: Contact, balance: Double)] {
        getContactsWithBalance()
            .filter { $0.direction == .owedToMe }
            .map { (contact: $0.contact, balance: $0.balance) }
            .sorted { $0.balance > $1.balance }
    }
    
    func contactsIOwe() -> [(contact: Contact, balance: Double)] {
        getContactsWithBalance()
            .filter { $0.direction == .iOwe }
            .map { (contact: $0.contact, balance: $0.balance) }
            .sorted { $0.balance > $1.balance }
    }
    
    func getTotalToReceive() -> Double {
        // Calculate from net balances per contact to handle cases where a contact
        // has both lent and borrowed transactions
        getContactsWithBalance()
            .filter { $0.direction == .owedToMe }
            .map { $0.balance }
            .reduce(0, +)
    }
    
    func getTotalToPay() -> Double {
        // Calculate from net balances per contact to handle cases where a contact
        // has both lent and borrowed transactions
        getContactsWithBalance()
            .filter { $0.direction == .iOwe }
            .map { $0.balance }
            .reduce(0, +)
    }
    
    // Get net debt (To Pay - To Receive, negative means net owed to me)
    func getNetDebt() -> Double {
        getTotalToPay() - getTotalToReceive()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Save contacts
        if let encoded = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(encoded, forKey: contactsKey)
        }
        
        // Save transactions
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: transactionsKey)
        }
    }
    
    private func loadData() {
        // Load contacts
        if let data = UserDefaults.standard.data(forKey: contactsKey),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = decoded
        }
        
        // Load transactions
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([DebtTransaction].self, from: data) {
            transactions = decoded
        }
    }
}

// MARK: - Helper Extensions

extension Contact {
    // Convert Contact + balance to Debt for display
    func toDebt(balance: Double, direction: DebtDirection, latestTransaction: DebtTransaction?) -> Debt {
        Debt(
            id: id,
            personName: name,
            amount: balance,
            direction: direction,
            note: latestTransaction?.note,
            date: latestTransaction?.date ?? Date(),
            iconName: "person.fill"
        )
    }
}
