//
//  TransactionManagerAdapter.swift
//  FinanceFlow
//
//  Adapter to bridge old TransactionManager interface with new architecture
//  This allows gradual migration without breaking existing Views
//

import Foundation
import SwiftUI
import Combine

/// Adapter that wraps new architecture (Repository + UseCases) 
/// but provides old TransactionManager interface for compatibility
final class TransactionManagerAdapter: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    private let viewModel: TransactionViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
        
        // Convert TransactionEntity to Transaction and publish
        viewModel.$transactions
            .map { entities in
                entities.map { entity in
                    Transaction(
                        id: entity.id,
                        title: entity.title,
                        category: entity.category,
                        amount: entity.amount,
                        date: entity.date,
                        type: entity.type,
                        accountId: entity.accountId,
                        toAccountId: entity.toAccountId,
                        currency: entity.currency,
                        sourcePlannedPaymentId: entity.sourcePlannedPaymentId,
                        occurrenceDate: entity.occurrenceDate
                    )
                }
            }
            .assign(to: \.transactions, on: self)
            .store(in: &cancellables)
    }
    
    func addTransaction(_ transaction: Transaction) {
        Task { @MainActor in
            let entity = TransactionEntity(
                id: transaction.id,
                title: transaction.title,
                category: transaction.category,
                amount: transaction.amount,
                date: transaction.date,
                type: transaction.type,
                accountId: transaction.accountId,
                toAccountId: transaction.toAccountId,
                currency: transaction.currency,
                sourcePlannedPaymentId: transaction.sourcePlannedPaymentId,
                occurrenceDate: transaction.occurrenceDate
            )
            await viewModel.createTransaction(entity)
        }
    }
    
    func updateTransaction(_ transaction: Transaction) {
        Task { @MainActor in
            let entity = TransactionEntity(
                id: transaction.id,
                title: transaction.title,
                category: transaction.category,
                amount: transaction.amount,
                date: transaction.date,
                type: transaction.type,
                accountId: transaction.accountId,
                toAccountId: transaction.toAccountId,
                currency: transaction.currency,
                sourcePlannedPaymentId: transaction.sourcePlannedPaymentId,
                occurrenceDate: transaction.occurrenceDate
            )
            await viewModel.updateTransaction(entity)
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        Task { @MainActor in
            await viewModel.deleteTransaction(id: transaction.id)
        }
    }
    
    func getTransaction(id: UUID) -> Transaction? {
        return transactions.first { $0.id == id }
    }
    
    func reset() {
        // Not implemented in new architecture - transactions are managed through repository
    }
}


