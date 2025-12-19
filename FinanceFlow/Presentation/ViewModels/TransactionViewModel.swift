//
//  TransactionViewModel.swift
//  FinanceFlow
//
//  ViewModel for transaction management - no data duplication
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for transaction management
/// Uses UseCases and subscribes to Repository publishers - no data duplication
@MainActor
final class TransactionViewModel: ObservableObject {
    // MARK: - Published Properties (UI State only)
    @Published var transactions: [TransactionEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let transactionRepository: TransactionRepositoryProtocol
    private let accountRepository: AccountRepositoryProtocol
    private let createUseCase: CreateTransactionUseCase
    private let updateUseCase: UpdateTransactionUseCase
    private let deleteUseCase: DeleteTransactionUseCase
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        accountRepository: AccountRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        
        self.createUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
        )
        
        self.updateUseCase = UpdateTransactionUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
        )
        
        self.deleteUseCase = DeleteTransactionUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
        )
        
        // Subscribe to repository publisher - Single Source of Truth
        transactionRepository.transactionsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.transactions, on: self)
            .store(in: &cancellables)
        
        // Load initial data
        Task {
            await loadTransactions()
        }
    }
    
    // MARK: - Public Methods
    
    func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await transactionRepository.getAllTransactions()
            // Data will be updated via publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createTransaction(_ transaction: TransactionEntity) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await createUseCase.execute(transaction)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateTransaction(_ transaction: TransactionEntity) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await updateUseCase.execute(transaction)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteTransaction(id: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await deleteUseCase.execute(id: id)
            // Data will be updated via repository publisher
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func getTransactions(
        accountId: UUID? = nil,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        type: TransactionType? = nil,
        limit: Int? = nil
    ) async -> [TransactionEntity] {
        do {
            return try await transactionRepository.getTransactions(
                accountId: accountId,
                fromDate: fromDate,
                toDate: toDate,
                type: type,
                limit: limit
            )
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
    
    func getTransaction(id: UUID) async -> TransactionEntity? {
        do {
            return try await transactionRepository.getTransaction(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Computed Properties for UI
    
    var todayTransactions: [TransactionEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return transactions.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate <= today
        }
        .sorted { $0.date > $1.date }
    }
    
    var futureTransactions: [TransactionEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return transactions.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate > today
        }
        .sorted { $0.date < $1.date }
    }
    
    func transactionsForAccount(_ accountId: UUID) -> [TransactionEntity] {
        transactions.filter { transaction in
            transaction.accountId == accountId || transaction.toAccountId == accountId
        }
        .sorted { $0.date > $1.date }
    }
}


