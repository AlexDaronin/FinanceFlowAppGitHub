//
//  Dependencies.swift
//  FinanceFlow
//
//  Dependency injection container
//

import Foundation
import SwiftData

/// Dependency injection container
/// Provides shared instances of repositories and use cases
final class Dependencies {
    static let shared = Dependencies()
    
    let transactionRepository: TransactionRepositoryProtocol
    let accountRepository: AccountRepositoryProtocol
    
    private init() {
        // This will be initialized from FinanceFlowApp with ModelContext
        fatalError("Use init(modelContext:) instead")
    }
    
    init(modelContext: ModelContext) {
        self.transactionRepository = TransactionRepository(modelContext: modelContext)
        self.accountRepository = AccountRepository(modelContext: modelContext)
    }
}


