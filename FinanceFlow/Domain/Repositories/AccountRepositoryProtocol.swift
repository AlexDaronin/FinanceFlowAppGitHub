//
//  AccountRepositoryProtocol.swift
//  FinanceFlow
//
//  Repository protocol for Account data access
//

import Foundation
import Combine

/// Protocol defining account data operations
/// Single Source of Truth for accounts
protocol AccountRepositoryProtocol {
    /// Get all accounts
    func getAllAccounts() async throws -> [AccountEntity]
    
    /// Get account by ID
    func getAccount(id: UUID) async throws -> AccountEntity?
    
    /// Create new account
    func createAccount(_ account: AccountEntity) async throws
    
    /// Update existing account
    func updateAccount(_ account: AccountEntity) async throws
    
    /// Delete account
    func deleteAccount(id: UUID) async throws
    
    /// Get default account ID
    func getDefaultAccountId() async throws -> UUID?
    
    /// Set default account ID
    func setDefaultAccountId(_ id: UUID?) async throws
    
    /// Publisher for account changes (reactive updates)
    var accountsPublisher: AnyPublisher<[AccountEntity], Never> { get }
}


