//
//  DebtManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class DebtManager: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var transactions: [DebtTransaction] = []
    
    private let contactsKey = "savedContacts"
    private let transactionsKey = "savedDebtTransactions"
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadData()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
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
    
    // MARK: - Reset
    
    func reset() {
        contacts = []
        transactions = []
        if let modelContext = modelContext {
            let contactsDescriptor = FetchDescriptor<SDContact>()
            let transactionsDescriptor = FetchDescriptor<SDDebtTransaction>()
            
            if let sdContacts = try? modelContext.fetch(contactsDescriptor) {
                for sdContact in sdContacts {
                    modelContext.delete(sdContact)
                }
            }
            
            if let sdTransactions = try? modelContext.fetch(transactionsDescriptor) {
                for sdTransaction in sdTransactions {
                    modelContext.delete(sdTransaction)
                }
            }
            
            try? modelContext.save()
        } else {
            UserDefaults.standard.removeObject(forKey: contactsKey)
            UserDefaults.standard.removeObject(forKey: transactionsKey)
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let encoded = try? JSONEncoder().encode(contacts) {
                UserDefaults.standard.set(encoded, forKey: contactsKey)
            }
            if let encoded = try? JSONEncoder().encode(transactions) {
                UserDefaults.standard.set(encoded, forKey: transactionsKey)
            }
            return
        }
        
        // Save contacts
        let contactsDescriptor = FetchDescriptor<SDContact>()
        guard let existingSDContacts = try? modelContext.fetch(contactsDescriptor) else { return }
        
        var contactsMap: [UUID: SDContact] = [:]
        for sdContact in existingSDContacts {
            contactsMap[sdContact.id] = sdContact
        }
        
        for contact in contacts {
            if let existing = contactsMap[contact.id] {
                existing.name = contact.name
                existing.avatarColor = contact.avatarColor
            } else {
                modelContext.insert(SDContact.from(contact))
            }
        }
        
        let contactIds = Set(contacts.map { $0.id })
        for sdContact in existingSDContacts {
            if !contactIds.contains(sdContact.id) {
                modelContext.delete(sdContact)
            }
        }
        
        // Save transactions
        let transactionsDescriptor = FetchDescriptor<SDDebtTransaction>()
        guard let existingSDTransactions = try? modelContext.fetch(transactionsDescriptor) else { return }
        
        var transactionsMap: [UUID: SDDebtTransaction] = [:]
        for sdTransaction in existingSDTransactions {
            transactionsMap[sdTransaction.id] = sdTransaction
        }
        
        for transaction in transactions {
            if let existing = transactionsMap[transaction.id] {
                existing.contactId = transaction.contactId
                existing.amount = transaction.amount
                existing.type = transaction.type.rawValue
                existing.date = transaction.date
                existing.note = transaction.note
                existing.isSettled = transaction.isSettled
                existing.accountId = transaction.accountId
                existing.currency = transaction.currency
                existing.createdAt = transaction.createdAt
                existing.updatedAt = transaction.updatedAt
            } else {
                modelContext.insert(SDDebtTransaction.from(transaction))
            }
        }
        
        let transactionIds = Set(transactions.map { $0.id })
        for sdTransaction in existingSDTransactions {
            if !transactionIds.contains(sdTransaction.id) {
                modelContext.delete(sdTransaction)
            }
        }
        
        try? modelContext.save()
    }
    
    private func loadData() {
        guard let modelContext = modelContext else {
            // Fallback to UserDefaults if ModelContext is not available
            if let data = UserDefaults.standard.data(forKey: contactsKey),
               let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
                contacts = decoded
            }
            if let data = UserDefaults.standard.data(forKey: transactionsKey),
               let decoded = try? JSONDecoder().decode([DebtTransaction].self, from: data) {
                transactions = decoded
            }
            return
        }
        
        // Load contacts
        let contactsDescriptor = FetchDescriptor<SDContact>()
        if let sdContacts = try? modelContext.fetch(contactsDescriptor) {
            contacts = sdContacts.map { $0.toContact() }
        }
        
        // Load transactions
        let transactionsDescriptor = FetchDescriptor<SDDebtTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let sdTransactions = try? modelContext.fetch(transactionsDescriptor) {
            transactions = sdTransactions.map { $0.toDebtTransaction() }
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
