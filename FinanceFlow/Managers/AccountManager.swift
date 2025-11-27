//
//  AccountManager.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI
import Combine

class AccountManager: ObservableObject {
    @Published var accounts: [Account] = []
    
    private let accountsKey = "savedAccounts"
    
    init() {
        loadData()
    }
    
    // MARK: - Account Management
    
    func addAccount(_ account: Account) {
        accounts.append(account)
        saveData()
    }
    
    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveData()
        }
    }
    
    func deleteAccount(_ accountId: UUID) {
        accounts.removeAll { $0.id == accountId }
        saveData()
    }
    
    func getAccount(id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }
    
    func getAccount(name: String) -> Account? {
        accounts.first { $0.name == name }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
    }
}

