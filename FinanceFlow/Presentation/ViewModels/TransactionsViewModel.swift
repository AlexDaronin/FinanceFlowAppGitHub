//
//  TransactionsViewModel.swift
//  FinanceFlow
//
//  Created for performance optimization
//

import Foundation
import Combine

/// ViewModel для кэширования вычислений транзакций и предотвращения лишних перерисовок
@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var filteredTransactions: [Transaction] = []
    @Published var futureTransactions: [Transaction] = []
    @Published var missedTransactions: [Transaction] = []
    @Published var groupedTransactions: [(date: Date, transactions: [Transaction])] = []
    @Published var groupedFutureTransactions: [(date: Date, transactions: [Transaction])] = []
    @Published var groupedMissedTransactions: [(date: Date, transactions: [Transaction])] = []
    @Published var categories: [String] = []
    
    private var allTransactions: [Transaction] = []
    private var searchText: String = ""
    private var selectedCategory: String? = nil
    private var selectedType: TransactionType? = nil
    private var accountManager: AccountManagerAdapter?
    
    private var updateTask: Task<Void, Never>?
    private let debounceDelay: TimeInterval = 0.15 // 150ms debounce
    
    // MARK: - Public Methods
    
    func update(
        transactions: [Transaction],
        searchText: String,
        selectedCategory: String?,
        selectedType: TransactionType?,
        accountManager: AccountManagerAdapter
    ) {
        // Проверяем, изменились ли входные данные
        let transactionsChanged = allTransactions.count != transactions.count || 
                                 !allTransactions.elementsEqual(transactions, by: { $0.id == $1.id })
        let searchChanged = self.searchText != searchText
        let categoryChanged = self.selectedCategory != selectedCategory
        let typeChanged = self.selectedType != selectedType
        
        // Если ничего не изменилось, не пересчитываем
        guard transactionsChanged || searchChanged || categoryChanged || typeChanged else {
            return
        }
        
        self.allTransactions = transactions
        self.searchText = searchText
        self.selectedCategory = selectedCategory
        self.selectedType = selectedType
        self.accountManager = accountManager
        
        // Отменяем предыдущую задачу
        updateTask?.cancel()
        
        // Создаем новую задачу с debounce
        updateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceDelay ?? 0.15 * 1_000_000_000))
            
            guard let self = self, !Task.isCancelled else { return }
            await self.recalculateAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func recalculateAll() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Предварительно вычисляем account names для всех транзакций
        let accountNameCache = Dictionary(
            uniqueKeysWithValues: allTransactions.map { transaction in
                (transaction.id, transaction.accountName(accountManager: accountManager!))
            }
        )
        
        // Фильтруем транзакции один раз
        let baseFiltered = allTransactions.filter { transaction in
            let accountName = accountNameCache[transaction.id] ?? ""
            let matchesSearch = searchText.isEmpty ||
                transaction.title.localizedCaseInsensitiveContains(searchText) ||
                transaction.category.localizedCaseInsensitiveContains(searchText) ||
                accountName.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || transaction.category == selectedCategory
            let matchesType = selectedType == nil || transaction.type == selectedType
            return matchesSearch && matchesCategory && matchesType
        }
        
        // Разделяем на прошлые и будущие
        let pastTransactions = baseFiltered.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate <= today
        }
        
        let futureTransactionsFiltered = baseFiltered.filter { transaction in
            let transactionDate = calendar.startOfDay(for: transaction.date)
            return transactionDate > today
        }
        
        // Сортируем
        self.filteredTransactions = pastTransactions.sorted { $0.date > $1.date }
        self.futureTransactions = futureTransactionsFiltered.sorted { $0.date < $1.date }
        
        // Группируем
        self.groupedTransactions = groupTransactions(filteredTransactions, calendar: calendar)
        self.groupedFutureTransactions = groupTransactions(futureTransactions, calendar: calendar)
        
        // Категории
        self.categories = Array(Set(allTransactions.map(\.category))).sorted()
        
        // Missed transactions вычисляются отдельно (более сложная логика)
        // Пока оставляем пустым, можно добавить позже если нужно
        self.missedTransactions = []
        self.groupedMissedTransactions = []
    }
    
    private func groupTransactions(
        _ transactions: [Transaction],
        calendar: Calendar
    ) -> [(date: Date, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
}

