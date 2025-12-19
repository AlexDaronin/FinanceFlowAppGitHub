//
//  TransactionRepository.swift
//  FinanceFlow
//
//  SwiftData implementation of TransactionRepositoryProtocol
//

import Foundation
import SwiftData
import Combine

/// SwiftData implementation of TransactionRepositoryProtocol
/// Single Source of Truth for transactions - no duplication
final class TransactionRepository: TransactionRepositoryProtocol {
    private let modelContext: ModelContext
    private let transactionsSubject = CurrentValueSubject<[TransactionEntity], Never>([])
    // Кэш для сравнения данных (чтобы не отправлять обновления без изменений)
    private var lastPublishedSignature: String = ""
    
    var transactionsPublisher: AnyPublisher<[TransactionEntity], Never> {
        transactionsSubject.eraseToAnyPublisher()
    }
    
    // Вычисляет "signature" списка транзакций для сравнения
    private func computeSignature(_ transactions: [TransactionEntity]) -> String {
        // Используем count + первые несколько ID для быстрого сравнения
        // Если count совпадает и первые ID совпадают, вероятно данные не изменились
        let ids = transactions.prefix(10).map { $0.id.uuidString }.joined(separator: ",")
        let count = transactions.count
        return "\(count):\(ids)"
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Repository Implementation
    
    func getAllTransactions() async throws -> [TransactionEntity] {
        let descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let sdTransactions = try modelContext.fetch(descriptor)
        let entities = sdTransactions.map { $0.toEntity() }
        
        // НЕ отправляем здесь - отправка происходит через refreshPublisher() при необходимости
        // Это предотвращает множественные обновления при одном изменении
        
        return entities
    }
    
    func getTransactions(
        accountId: UUID?,
        fromDate: Date?,
        toDate: Date?,
        type: TransactionType?,
        limit: Int?
    ) async throws -> [TransactionEntity] {
        // Build combined predicate
        let predicate: Predicate<SDTransaction>?
        
        if let accountId = accountId, let fromDate = fromDate, let toDate = toDate, let type = type {
            predicate = #Predicate<SDTransaction> { transaction in
                (transaction.accountId == accountId || transaction.toAccountId == accountId) &&
                transaction.date >= fromDate &&
                transaction.date <= toDate &&
                transaction.type == type.rawValue
            }
        } else if let accountId = accountId, let fromDate = fromDate, let toDate = toDate {
            predicate = #Predicate<SDTransaction> { transaction in
                (transaction.accountId == accountId || transaction.toAccountId == accountId) &&
                transaction.date >= fromDate &&
                transaction.date <= toDate
            }
        } else if let accountId = accountId, let type = type {
            predicate = #Predicate<SDTransaction> { transaction in
                (transaction.accountId == accountId || transaction.toAccountId == accountId) &&
                transaction.type == type.rawValue
            }
        } else if let accountId = accountId {
            predicate = #Predicate<SDTransaction> { transaction in
                transaction.accountId == accountId || transaction.toAccountId == accountId
            }
        } else if let fromDate = fromDate, let toDate = toDate {
            predicate = #Predicate<SDTransaction> { transaction in
                transaction.date >= fromDate && transaction.date <= toDate
            }
        } else if let type = type {
            predicate = #Predicate<SDTransaction> { transaction in
                transaction.type == type.rawValue
            }
        } else {
            predicate = nil
        }
        
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        let sdTransactions = try modelContext.fetch(descriptor)
        return sdTransactions.map { $0.toEntity() }
    }
    
    func getTransaction(id: UUID) async throws -> TransactionEntity? {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { $0.id == id }
        )
        
        guard let sdTransaction = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return sdTransaction.toEntity()
    }
    
    func createTransaction(_ transaction: TransactionEntity) async throws {
        let sdTransaction = SDTransaction.from(transaction)
        modelContext.insert(sdTransaction)
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func updateTransaction(_ transaction: TransactionEntity) async throws {
        let transactionId = transaction.id
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { $0.id == transactionId }
        )
        
        guard let sdTransaction = try modelContext.fetch(descriptor).first else {
            throw TransactionError.transactionNotFound
        }
        
        // Update properties
        sdTransaction.title = transaction.title
        sdTransaction.category = transaction.category
        sdTransaction.amount = transaction.amount
        sdTransaction.date = transaction.date
        sdTransaction.type = transaction.type.rawValue
        sdTransaction.accountId = transaction.accountId
        sdTransaction.toAccountId = transaction.toAccountId
        sdTransaction.currency = transaction.currency
        sdTransaction.sourcePlannedPaymentId = transaction.sourcePlannedPaymentId
        sdTransaction.occurrenceDate = transaction.occurrenceDate
        
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func deleteTransaction(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { $0.id == id }
        )
        
        guard let sdTransaction = try modelContext.fetch(descriptor).first else {
            throw TransactionError.transactionNotFound
        }
        
        modelContext.delete(sdTransaction)
        try modelContext.save()
        
        await refreshPublisher()
    }
    
    func deleteTransactions(ids: [UUID]) async throws {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { ids.contains($0.id) }
        )
        
        let sdTransactions = try modelContext.fetch(descriptor)
        for sdTransaction in sdTransactions {
            modelContext.delete(sdTransaction)
        }
        
        try modelContext.save()
        await refreshPublisher()
    }
    
    func getTransactionsCount() async throws -> Int {
        let descriptor = FetchDescriptor<SDTransaction>()
        return try modelContext.fetchCount(descriptor)
    }
    
    func transactionExists(sourceId: UUID, date: Date) async throws -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDate) ?? normalizedDate
        
        let predicate = #Predicate<SDTransaction> { transaction in
            transaction.sourcePlannedPaymentId == sourceId &&
            transaction.date >= normalizedDate &&
            transaction.date < nextDay
        }
        
        var descriptor = FetchDescriptor<SDTransaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }
    
    func fetchTransactions(sourceId: UUID) async throws -> [TransactionEntity] {
        let predicate = #Predicate<SDTransaction> { transaction in
            transaction.sourcePlannedPaymentId == sourceId
        }
        
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let sdTransactions = try modelContext.fetch(descriptor)
        return sdTransactions.map { $0.toEntity() }
    }
    
    func deleteTransactions(sourceId: UUID) async throws {
        let predicate = #Predicate<SDTransaction> { transaction in
            transaction.sourcePlannedPaymentId == sourceId
        }
        
        let descriptor = FetchDescriptor<SDTransaction>(predicate: predicate)
        let sdTransactions = try modelContext.fetch(descriptor)
        
        for sdTransaction in sdTransactions {
            modelContext.delete(sdTransaction)
        }
        
        try modelContext.save()
        await refreshPublisher()
    }
    
    // MARK: - Private Helpers
    
    private func loadInitialData() async {
        do {
            let transactions = try await getAllTransactions()
            // Для initial load всегда отправляем
            await MainActor.run {
                lastPublishedSignature = computeSignature(transactions)
                transactionsSubject.send(transactions)
            }
        } catch {
            print("Error loading initial transactions: \(error)")
        }
    }
    
    private func refreshPublisher() async {
        do {
            let transactions = try await getAllTransactions()
            // Отправляем только если данные изменились
            await MainActor.run {
                let newSignature = computeSignature(transactions)
                if newSignature != lastPublishedSignature {
                    lastPublishedSignature = newSignature
                    transactionsSubject.send(transactions)
                }
            }
        } catch {
            print("Error refreshing transactions: \(error)")
        }
    }
}

// MARK: - SwiftData Model Extension
extension SDTransaction {
    func toEntity() -> TransactionEntity {
        TransactionEntity(
            id: id,
            title: title,
            category: category,
            amount: amount,
            date: date,
            type: TransactionType(rawValue: type) ?? .expense,
            accountId: accountId,
            toAccountId: toAccountId,
            currency: currency,
            sourcePlannedPaymentId: sourcePlannedPaymentId,
            occurrenceDate: occurrenceDate
        )
    }
    
    static func from(_ entity: TransactionEntity) -> SDTransaction {
        SDTransaction(
            id: entity.id,
            title: entity.title,
            category: entity.category,
            amount: entity.amount,
            date: entity.date,
            type: entity.type.rawValue,
            accountId: entity.accountId,
            toAccountId: entity.toAccountId,
            currency: entity.currency,
            sourcePlannedPaymentId: entity.sourcePlannedPaymentId,
            occurrenceDate: entity.occurrenceDate
        )
    }
}


