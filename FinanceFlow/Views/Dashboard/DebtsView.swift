//
//  DebtsView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct DebtsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var debtManager: DebtManager
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @State private var showDebtForm = false
    @State private var selectedContact: Contact?
    @State private var owedToMeExpanded = true
    @State private var iOweExpanded = true
    
    private var contactsOwedToMe: [(contact: Contact, balance: Double)] {
        debtManager.contactsOwedToMe()
    }
    
    private var contactsIOwe: [(contact: Contact, balance: Double)] {
        debtManager.contactsIOwe()
    }
    
    private var totalOwedToMe: Double {
        debtManager.getTotalToReceive()
    }
    
    private var totalIOwe: Double {
        debtManager.getTotalToPay()
    }
    
    private var netDebt: Double {
        totalOwedToMe - totalIOwe
    }
    
    // MARK: - Summary Cards Section
    @ViewBuilder
    private var summaryCardsSection: some View {
        // Show two separate cards: one for "owed to me" and one for "I owe"
        HStack(spacing: 12) {
            // "Owed to me" card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(String(localized: "Owed to me", comment: "Owed to me label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(currencyString(totalOwedToMe, code: settings.currency))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // "I owe" card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(String(localized: "I owe", comment: "I owe label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(currencyString(totalIOwe, code: settings.currency))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Debts", comment: "Debts title"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(String(localized: "Track money between people", comment: "Debts description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Summary Cards
                        summaryCardsSection
                            .padding(.horizontal)
                        
                        // To Receive section
                        debtGroupSection(
                            title: String(localized: "Owed to me", comment: "Owed to me section"),
                            contacts: contactsOwedToMe,
                            total: totalOwedToMe,
                            color: .green,
                            icon: "arrow.down.circle.fill",
                            isExpanded: $owedToMeExpanded
                        )
                        
                        // To Pay section
                        debtGroupSection(
                            title: String(localized: "I owe", comment: "I owe section"),
                            contacts: contactsIOwe,
                            total: totalIOwe,
                            color: .red,
                            icon: "arrow.up.circle.fill",
                            isExpanded: $iOweExpanded
                        )
                    }
                    .padding(.bottom, 120)
                }
                
                // Floating Action Button
                floatingActionButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDebtForm) {
                DebtFormView(
                    contact: selectedContact,
                    debtManager: debtManager,
                    onSave: { contact, transaction in
                        handleSave(contact: contact, transaction: transaction)
                    },
                    onCancel: {
                        showDebtForm = false
                        selectedContact = nil
                    }
                )
                .environmentObject(settings)
                .environmentObject(accountManager)
                .environmentObject(transactionManager)
            }
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(debtManager: debtManager, contact: contact)
                    .environmentObject(settings)
                    .environmentObject(accountManager)
                    .environmentObject(transactionManager)
            }
        }
    }
    
    private func debtGroupSection(
        title: String,
        contacts: [(contact: Contact, balance: Double)],
        total: Double,
        color: Color,
        icon: String,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Total amount (only if not zero)
                    if total > 0.01 {
                        Text(currencyString(total, code: settings.currency))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(color)
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded.wrappedValue)
                }
                .padding(.horizontal)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Contact cards container with smooth expand/collapse
            // Content always rendered, animated with opacity and clipped for 60fps performance
            VStack(alignment: .leading, spacing: 10) {
                if contacts.isEmpty {
                    emptyStateView(for: title)
                        .padding(.horizontal)
                        .padding(.top, 12)
                } else {
                    ForEach(contacts, id: \.contact.id) { item in
                        let latestTransaction = debtManager.getTransactions(for: item.contact.id).first
                        ContactCard(
                            contact: item.contact,
                            balance: item.balance,
                            color: color,
                            latestTransaction: latestTransaction,
                            onTap: {
                                selectedContact = item.contact
                            },
                            onDelete: {
                                // Delete contact and all associated transactions
                                let contactToDelete = item.contact
                                let transactionsToRevert = debtManager.getTransactions(for: contactToDelete.id)
                                
                                // Revert account balances and delete transactions
                                for transaction in transactionsToRevert {
                                    // Delete corresponding Transaction
                                    // Balance is reverted automatically by DeleteTransactionUseCase
                                    if let transactionToDelete = transactionManager.getTransaction(id: transaction.id) {
                                        transactionManager.deleteTransaction(transactionToDelete)
                                    }
                                }
                                
                                debtManager.deleteContact(contactToDelete)
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: isExpanded.wrappedValue ? 10000 : 0)
            .opacity(isExpanded.wrappedValue ? 1 : 0)
            .clipped()
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded.wrappedValue)
        }
    }
    
    private func emptyStateView(for title: String) -> some View {
        VStack(spacing: 8) {
            Text(String(localized: "No debts", comment: "No debts message"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    // Standardized Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                // --- BUTTON ---
                Button {
                    selectedContact = nil
                    showDebtForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56) // Fixed standard size
                        .background(
                            Circle()
                                .fill(Color.orange) // <--- Change this per view
                                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 6)
                        )
                }
                // ----------------
                }
            .padding(.trailing, 20) // Fixed right margin
            .padding(.bottom, 110)   // Fixed bottom margin (optimized for thumb reach)
        }
        .ignoresSafeArea() // CRITICAL: Pins button relative to screen edge, ignoring layout differences
    }
    
    private func handleSave(contact: Contact, transaction: DebtTransaction) {
        // Save or update contact
        if debtManager.contacts.contains(where: { $0.id == contact.id }) {
            debtManager.updateContact(contact)
        } else {
            debtManager.addContact(contact)
        }
        
        // Check if this is an update or new transaction
        let isUpdate = debtManager.transactions.contains(where: { $0.id == transaction.id })
        
        // Save or update debt transaction
        if isUpdate {
            debtManager.updateTransaction(transaction)
        } else {
            debtManager.addTransaction(transaction)
        }
        
        // Create or update corresponding Transaction
        let transactionTitle: String
        if let note = transaction.note, !note.isEmpty {
            transactionTitle = note
        } else {
            switch transaction.type {
            case .lent:
                transactionTitle = "Lent to \(contact.name)"
            case .lentReturn:
                transactionTitle = "Returned debt from \(contact.name)"
            case .borrowed:
                transactionTitle = "Borrowed from \(contact.name)"
            case .borrowedReturn:
                transactionTitle = "Returned debt to \(contact.name)"
            }
        }
        // Map debt transaction type to transaction type for balance updates
        // "Мне дали в долг" и "Мне вернули долг" → income (деньги приходят)
        // "Я дал в долг" и "Я вернул долг" → expense (деньги уходят)
        let regularTransactionType: TransactionType
        switch transaction.type {
        case .borrowed, .borrowedReturn:
            regularTransactionType = .income
        case .lent, .lentReturn:
            regularTransactionType = .expense
        }
        
        let regularTransaction = Transaction(
            id: transaction.id, // Use same ID to link them
            title: transactionTitle,
            category: "Debt",
            amount: transaction.amount,
            date: transaction.date,
            type: regularTransactionType,
            accountId: transaction.accountId,
            toAccountId: nil,
            currency: transaction.currency
        )
        
        if isUpdate {
            // Update existing transaction if it exists
            if transactionManager.getTransaction(id: transaction.id) != nil {
                transactionManager.updateTransaction(regularTransaction)
            } else {
                // If transaction doesn't exist, create it
                transactionManager.addTransaction(regularTransaction)
            }
        } else {
            // Create new transaction only if it doesn't already exist (prevent duplication)
            if transactionManager.getTransaction(id: transaction.id) == nil {
                transactionManager.addTransaction(regularTransaction)
            }
        }
        
        showDebtForm = false
        selectedContact = nil
    }
}

struct ContactCard: View {
    @EnvironmentObject var settings: AppSettings
    let contact: Contact
    let balance: Double
    let color: Color
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    let latestTransaction: DebtTransaction?
    
    init(contact: Contact, balance: Double, color: Color, latestTransaction: DebtTransaction? = nil, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.contact = contact
        self.balance = balance
        self.color = color
        self.latestTransaction = latestTransaction
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // Avatar with initials
                ZStack {
                    Circle()
                        .fill(contact.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(contact.color)
                }
                
                // Name
                Text(contact.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Amount
                Text(currencyString(abs(balance), code: settings.currency))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Contact", systemImage: "trash")
                }
            }
        }
    }
}

struct DebtFormView: View {
    let contact: Contact?
    let debtManager: DebtManager
    let onSave: (Contact, DebtTransaction) -> Void
    let onCancel: () -> Void
    let onDelete: ((DebtTransaction) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @State private var selectedContact: Contact?
    @State private var showContactPicker = false
    @State private var showAccountPicker = false
    @State private var transactionType: DebtTransactionType = .lent
    @State private var isReturn: Bool = false // Whether this is a return transaction
    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var accountId: UUID = UUID()
    @State private var currency: String = "USD"
    @State private var editingTransaction: DebtTransaction?
    @State private var showDeleteAlert = false
    @State private var showCreateContact = false
    @State private var newContactName = ""
    
    @FocusState private var isAmountFocused: Bool
    
    // MARK: - Dismiss Keyboard Helper
    private func dismissKeyboard() {
        isAmountFocused = false
        // Also dismiss any other first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    init(contact: Contact? = nil, debtManager: DebtManager, editingTransaction: DebtTransaction? = nil, onSave: @escaping (Contact, DebtTransaction) -> Void, onCancel: @escaping () -> Void, onDelete: ((DebtTransaction) -> Void)? = nil) {
        self.contact = contact
        self.debtManager = debtManager
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        _selectedContact = State(initialValue: contact)
        _editingTransaction = State(initialValue: editingTransaction)
        if let transaction = editingTransaction {
            _amount = State(initialValue: transaction.amount)
            _date = State(initialValue: transaction.date)
            _note = State(initialValue: transaction.note ?? "")
            _transactionType = State(initialValue: transaction.type)
            _isReturn = State(initialValue: transaction.type.isReturn)
            _accountId = State(initialValue: transaction.accountId)
            _currency = State(initialValue: transaction.currency)
            if let contact = debtManager.getContact(id: transaction.contactId) {
                _selectedContact = State(initialValue: contact)
            }
        } else {
            // For new transactions, use default account - will be set in onAppear
            _accountId = State(initialValue: UUID())
        }
    }
    
    init(contact: Contact? = nil, debtManager: DebtManager, editingTransaction: DebtTransaction? = nil, onSave: @escaping (Contact, DebtTransaction) -> Void, onCancel: @escaping () -> Void) {
        self.contact = contact
        self.debtManager = debtManager
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = nil
        _selectedContact = State(initialValue: contact)
        _editingTransaction = State(initialValue: editingTransaction)
        if let transaction = editingTransaction {
            _amount = State(initialValue: transaction.amount)
            _date = State(initialValue: transaction.date)
            _note = State(initialValue: transaction.note ?? "")
            _transactionType = State(initialValue: transaction.type)
            _isReturn = State(initialValue: transaction.type.isReturn)
            _accountId = State(initialValue: transaction.accountId)
            _currency = State(initialValue: transaction.currency)
            if let contact = debtManager.getContact(id: transaction.contactId) {
                _selectedContact = State(initialValue: contact)
            }
        } else {
            // For new transactions, use default account - will be set in onAppear
            _accountId = State(initialValue: UUID())
        }
    }
    
    private var selectedAccount: Account? {
        accountManager.getAccount(id: accountId) ?? accountManager.accounts.first
    }
    
    // MARK: - Theme Color
    private var themeColor: Color {
        transactionType.direction.color
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
            ScrollView {
                    VStack(spacing: 24) {
                        // Custom Segmented Control at Top
                        typeSegmentedControl
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Hero Amount Input (Center)
                        heroAmountField
                            .padding(.horizontal)
                        
                        // Input Fields
                    VStack(spacing: 16) {
                            // Note Field
                            TransactionFormRow(
                                icon: "text.alignleft",
                                title: String(localized: "Note", comment: "Note field"),
                                value: $note,
                                placeholder: String(localized: "Transaction note", comment: "Transaction note placeholder")
                            )
                            
                            // Contact Row
                            TransactionContactRow(
                                icon: "person.fill",
                                title: String(localized: "Contact", comment: "Contact field label"),
                                contact: selectedContact,
                                placeholder: String(localized: "Select Contact", comment: "Select contact placeholder"),
                                onTap: {
                                    dismissKeyboard()
                                    showContactPicker = true
                                }
                            )
                            
                            
                            // Date Field
                            TransactionDateRow(
                                icon: "calendar",
                                title: String(localized: "Date", comment: "Date field"),
                                date: $date
                            )
                            
                            // Account Field
                            TransactionAccountRow(
                                icon: "creditcard",
                                title: String(localized: "Account", comment: "Account field label"),
                                account: selectedAccount,
                                placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                                onTap: {
                                    dismissKeyboard()
                                    showAccountPicker = true
                                }
                            )
                            
                            // Currency Field
                            TransactionCurrencyRow(
                                icon: "dollarsign.circle",
                                title: String(localized: "Currency", comment: "Currency field label"),
                                currency: $currency
                            )
                        }
                        .padding(.horizontal)
                        
                        // Save Button
                        Button {
                            dismissKeyboard()
                            handleSave()
                        } label: {
                            Text(String(localized: "Save", comment: "Save button"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? themeColor : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!isValid)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }
            }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        dismissKeyboard()
                    }
                )
            }
            .navigationTitle(editingTransaction == nil ? String(localized: "New Transaction", comment: "New transaction title") : String(localized: "Edit Debt", comment: "Edit debt title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                // Delete button (only when editing and onDelete is provided)
                if editingTransaction != nil, onDelete != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .alert(String(localized: "Delete Transaction", comment: "Delete transaction alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    if let transaction = editingTransaction {
                        onDelete?(transaction)
                        dismiss()
                }
                }
            } message: {
                Text(String(localized: "Are you sure you want to delete this transaction? This action cannot be undone.", comment: "Delete transaction confirmation"))
            }
            .sheet(isPresented: $showContactPicker) {
                contactPickerSheet
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet
            }
            .onAppear {
                // Initialize amount text from amount
                if amount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(amount)
                }
                // Initialize currency from settings for new transactions
                if editingTransaction == nil {
                    currency = settings.currency
                }
                // Initialize accountId if not set - use default account or first available
                if accountId == UUID() || accountManager.getAccount(id: accountId) == nil {
                    accountId = accountManager.getDefaultAccountId() ?? accountManager.accounts.first?.id ?? UUID()
                }
                // Sync isReturn with transactionType
                isReturn = transactionType.isReturn
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
            .onChange(of: transactionType) { oldValue, newValue in
                // Sync isReturn when transactionType changes
                isReturn = newValue.isReturn
            }
            .onChange(of: amount) { oldValue, newValue in
                // Sync amountText when amount changes externally
                if newValue == 0 {
                    amountText = ""
                } else if amountText.isEmpty || abs(newValue - (Double(amountText) ?? 0)) > 0.01 {
                    amountText = formatAmount(newValue)
            }
        }
        }
        .presentationDetents([.large])
    }
    
    private var isValid: Bool {
        selectedContact != nil && amount > 0 && selectedAccount != nil
    }
    
    private func handleSave() {
        guard let finalContact = selectedContact,
              let account = selectedAccount else { return }
        
        let transaction = DebtTransaction(
            id: editingTransaction?.id ?? UUID(),
            contactId: finalContact.id,
            amount: amount,
            type: transactionType,
            date: date,
            note: note.isEmpty ? nil : note,
            isSettled: editingTransaction?.isSettled ?? false,
            accountId: account.id,
            currency: currency
        )
        
        // Create or update corresponding Transaction
        // Balance is updated automatically by CreateTransactionUseCase or UpdateTransactionUseCase
        let transactionTitle: String
        if note.isEmpty {
            switch transactionType {
            case .lent:
                transactionTitle = "Lent to \(finalContact.name)"
            case .lentReturn:
                transactionTitle = "Returned debt from \(finalContact.name)"
            case .borrowed:
                transactionTitle = "Borrowed from \(finalContact.name)"
            case .borrowedReturn:
                transactionTitle = "Returned debt to \(finalContact.name)"
            }
        } else {
            transactionTitle = note
        }
        
        // Map debt transaction type to transaction type for balance updates
        // "Мне дали в долг" и "Мне вернули долг" → income (деньги приходят)
        // "Я дал в долг" и "Я вернул долг" → expense (деньги уходят)
        let regularTransactionType: TransactionType
        switch transactionType {
        case .borrowed, .borrowedReturn:
            regularTransactionType = .income
        case .lent, .lentReturn:
            regularTransactionType = .expense
        }
        
        let regularTransaction = Transaction(
            id: transaction.id, // Use same ID to link them
            title: transactionTitle,
            category: "Debt",
            amount: amount,
            date: date,
            type: regularTransactionType,
            accountId: account.id,
            toAccountId: nil,
            currency: currency
        )
        
        let isUpdate = editingTransaction != nil
        if isUpdate {
            // Update existing transaction if it exists
            if transactionManager.getTransaction(id: transaction.id) != nil {
                transactionManager.updateTransaction(regularTransaction)
            } else {
                // If transaction doesn't exist, create it
                transactionManager.addTransaction(regularTransaction)
            }
        } else {
            // Create new transaction only if it doesn't already exist (prevent duplication)
            if transactionManager.getTransaction(id: transaction.id) == nil {
                transactionManager.addTransaction(regularTransaction)
            }
        }
        
        onSave(finalContact, transaction)
        dismiss()
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach([DebtTransactionType.lent, DebtTransactionType.borrowed]) { type in
                Button {
                    dismissKeyboard()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        // If tapping the same type, toggle between normal and return
                        if transactionType.baseType == type {
                            // Toggle between normal and return
                            if transactionType.isReturn {
                                transactionType = type // Switch to normal
                            } else {
                                transactionType = type == .lent ? .lentReturn : .borrowedReturn // Switch to return
                            }
                        } else {
                            // Switch to different direction, preserve return state if applicable
                            if transactionType.isReturn {
                                transactionType = type == .lent ? .lentReturn : .borrowedReturn
                            } else {
                                transactionType = type
                            }
                        }
                        isReturn = transactionType.isReturn
                    }
                } label: {
                    Text(type == .lent ? String(localized: "I lent / I returned debt", comment: "I lent or returned") : String(localized: "They lent / They returned debt", comment: "They lent or returned"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transactionType.baseType == type ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(transactionType.baseType == type ? type.direction.color : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Hero Amount Field
    private var heroAmountField: some View {
        VStack(spacing: 8) {
            Text("Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Spacer()
                
                // Icon for debt transaction (matching screenshot style)
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                TextField("0", text: $amountText)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isAmountFocused)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 120)
                    .onChange(of: amountText) { oldValue, newValue in
                        handleAmountInput(newValue)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Amount Input Handler
    private func handleAmountInput(_ newValue: String) {
        // Normalize input to accept both dots and commas
        var cleaned = newValue.replacingOccurrences(of: ",", with: ".")
        cleaned = cleaned.filter { $0.isNumber || $0 == "." }
        let components = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        if components.count > 2 {
            let firstPart = String(components[0])
            let rest = components.dropFirst().joined(separator: "")
            cleaned = firstPart + "." + rest
        }
        
        // Handle leading zero replacement
        if amount == 0 && !cleaned.isEmpty {
            if let firstChar = cleaned.first, firstChar.isNumber, firstChar != "0" {
                amountText = cleaned
                if let value = Double(cleaned) {
                    amount = value
                }
                return
            }
                }
                
        // Update the text
        amountText = cleaned
        
        // Convert to double and update amount
        if cleaned.isEmpty {
            amount = 0
        } else if let value = Double(cleaned) {
            amount = value
        }
    }
    
    // MARK: - Format Amount
    private func formatAmount(_ amount: Double) -> String {
        // Format without trailing zeros
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            let formatted = String(format: "%.2f", amount)
            // Remove trailing zeros
            return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        }
    
    // MARK: - Contact Picker Sheet
    private var contactPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // Create new contact button at top
                    createNewContactButton
                    
                    // Existing contacts
                    ForEach(debtManager.contacts) { contact in
                        contactPickerItem(contact: contact)
                    }
                }
                .padding()
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "Select Contact", comment: "Select contact title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        showContactPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showCreateContact) {
            createContactSheet
        }
    }
    
    private var createNewContactButton: some View {
        Button {
            showCreateContact = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(String(localized: "Create New Contact", comment: "Create new contact button"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var createContactSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Contact Name", comment: "Contact name label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "Enter name", comment: "Enter name placeholder"), text: $newContactName)
                        .font(.subheadline)
                        .padding(16)
                        .background(Color.customCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding()
                
                Spacer()
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "New Contact", comment: "New contact title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        newContactName = ""
                        showCreateContact = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", comment: "Save button")) {
                        let trimmedName = newContactName.trimmingCharacters(in: .whitespaces)
                        if !trimmedName.isEmpty {
                            let color = Contact.generateColor(for: trimmedName)
                            let newContact = Contact(name: trimmedName, avatarColor: color)
                            debtManager.addContact(newContact)
                            selectedContact = newContact
                            newContactName = ""
                            showCreateContact = false
                            showContactPicker = false
                        }
                    }
                    .disabled(newContactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    private func contactPickerItem(contact: Contact) -> some View {
        Button {
            selectedContact = contact
            showContactPicker = false
        } label: {
            HStack {
                Circle()
                    .fill(contact.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.initials)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if selectedContact?.id == contact.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(selectedContact?.id == contact.id ? Color.blue.opacity(0.1) : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Account Picker Sheet
    private var accountPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accountManager.accounts) { account in
                        accountPickerItem(account: account)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "Select Account", comment: "Select account title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        showAccountPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func accountPickerItem(account: Account) -> some View {
        Button {
            accountId = account.id
            showAccountPicker = false
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: account.iconName)
                        .font(.title3)
                        .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(currencyString(account.balance, code: account.currency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if accountId == account.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background(accountId == account.id ? Color.accentColor.opacity(0.1) : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accountId == account.id ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: accountId == account.id ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Debt Contact Row Component (deprecated - using TransactionContactRow now)
struct DebtContactRow: View {
    let contact: Contact?
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let contact = contact {
                ZStack {
                    Circle()
                            .fill(contact.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text(contact.initials)
                            .font(.subheadline)
                            .foregroundStyle(contact.color)
                }
                    .frame(width: 24)
                    
                    Text(String(localized: "Contact", comment: "Contact label"))
                        .font(.body)
                        .foregroundStyle(.primary)
                
                Spacer()
                
                    Text(contact.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "person.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(String(localized: "Contact", comment: "Contact label"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(String(localized: "Select or create contact", comment: "Select contact placeholder"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ContactPickerView: View {
    let contacts: [Contact]
    @Binding var selectedContact: Contact?
    let onSelect: (Contact) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    createNewContactButton
                    existingContactsList
                }
                .padding(.vertical)
            }
            .background(Color.customBackground)
            .navigationTitle(String(localized: "Select Contact", comment: "Select contact title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var createNewContactButton: some View {
        Button {
            onCreateNew()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(String(localized: "Create New Contact", comment: "Create new contact button"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var existingContactsList: some View {
        ForEach(contacts) { contact in
            contactRow(for: contact)
        }
    }
    
    private func contactRow(for contact: Contact) -> some View {
        Button {
            onSelect(contact)
        } label: {
            contactRowContent(for: contact)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func contactRowContent(for contact: Contact) -> some View {
        HStack(spacing: 12) {
            contactAvatar(for: contact)
            Text(contact.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            Spacer()
            if selectedContact?.id == contact.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(16)
        .background(contactRowBackground(for: contact))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(contactRowOverlay(for: contact))
    }
    
    private func contactAvatar(for contact: Contact) -> some View {
        ZStack {
            Circle()
                .fill(contact.color.opacity(0.2))
                .frame(width: 48, height: 48)
            Text(contact.initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(contact.color)
        }
    }
    
    private func contactRowBackground(for contact: Contact) -> Color {
        selectedContact?.id == contact.id ? Color.accentColor.opacity(0.1) : Color.customCardBackground
    }
    
    private func contactRowOverlay(for contact: Contact) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                selectedContact?.id == contact.id ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08),
                lineWidth: selectedContact?.id == contact.id ? 1.5 : 1
            )
    }
}

struct CreateContactView: View {
    @Binding var contactName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Contact Name", comment: "Contact name label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter name", text: $contactName)
                        .font(.subheadline)
                        .padding(16)
                        .background(Color.customCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .focused($isNameFocused)
                }
                .padding()
                
                Spacer()
            }
            .background(Color.customBackground)
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", comment: "Save button")) {
                        onSave(contactName.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(contactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.height(200)])
    }
}

struct ContactDetailView: View {
    @ObservedObject var debtManager: DebtManager
    let contact: Contact
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var accountManager: AccountManagerAdapter
    @EnvironmentObject var transactionManager: TransactionManagerAdapter
    @State private var showEditContact = false
    @State private var showAddTransaction = false
    @State private var editingTransaction: DebtTransaction?
    @State private var showDeleteAlert = false
    @State private var showDeleteTransactionAlert = false
    @State private var transactionToDelete: DebtTransaction?
    
    private var contactTransactions: [DebtTransaction] {
        debtManager.getTransactions(for: contact.id)
    }
    
    private var netBalance: Double {
        contact.netBalance(from: debtManager.transactions)
    }
    
    private var balanceDirection: DebtDirection {
        netBalance > 0 ? .owedToMe : .iOwe
    }
    
    private var currentContact: Contact? {
        debtManager.getContact(id: contact.id)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with avatar and name
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill((currentContact?.color ?? contact.color).opacity(0.2))
                                    .frame(width: 64, height: 64)
                                Text((currentContact?.initials ?? contact.initials))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(currentContact?.color ?? contact.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentContact?.name ?? contact.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("Contact")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                showEditContact = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 36)
                            }
                        }
                        
                        // Balance card
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Net Balance", comment: "Net balance label"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currencyString(abs(netBalance), code: settings.currency))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(balanceDirection.color)
                            Text(balanceDirection == .owedToMe ? "They owe you" : "You owe them")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.customCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
                    }
                    .padding()
                    
                    // Transactions section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Transaction History")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                editingTransaction = nil
                                showAddTransaction = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28, height: 28)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        
                        if contactTransactions.isEmpty {
                            VStack(spacing: 8) {
                                Text(String(localized: "No transactions yet", comment: "No transactions message"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(contactTransactions) { transaction in
                                    TransactionHistoryRow(transaction: transaction) {
                                        editingTransaction = transaction
                                        showAddTransaction = true
                                    } onDelete: {
                                        transactionToDelete = transaction
                                        showDeleteTransactionAlert = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Delete contact button
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Delete Contact", comment: "Delete contact button"))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.customBackground)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditContact) {
                EditContactView(
                    contact: currentContact ?? contact,
                    debtManager: debtManager,
                    onSave: { updatedContact in
                        debtManager.updateContact(updatedContact)
                        showEditContact = false
                    },
                    onCancel: {
                        showEditContact = false
                    }
                )
            }
            .sheet(isPresented: $showAddTransaction) {
                DebtFormView(
                    contact: currentContact ?? contact,
                    debtManager: debtManager,
                    editingTransaction: editingTransaction,
                    onSave: { contact, transaction in
                        if debtManager.contacts.contains(where: { $0.id == contact.id }) {
                            debtManager.updateContact(contact)
                        } else {
                            debtManager.addContact(contact)
                        }
                        
                        let isUpdate = editingTransaction != nil
                        
                        if isUpdate {
                            debtManager.updateTransaction(transaction)
                        } else {
                            debtManager.addTransaction(transaction)
                        }
                        
                        // Create or update corresponding Transaction
                        let transactionTitle: String
                        if let note = transaction.note, !note.isEmpty {
                            transactionTitle = note
                        } else {
                            switch transaction.type {
                            case .lent:
                                transactionTitle = "Lent to \(contact.name)"
                            case .lentReturn:
                                transactionTitle = "Returned debt from \(contact.name)"
                            case .borrowed:
                                transactionTitle = "Borrowed from \(contact.name)"
                            case .borrowedReturn:
                                transactionTitle = "Returned debt to \(contact.name)"
                            }
                        }
                        // Map debt transaction type to transaction type for balance updates
                        // "Мне дали в долг" и "Мне вернули долг" → income (деньги приходят)
                        // "Я дал в долг" и "Я вернул долг" → expense (деньги уходят)
                        let regularTransactionType: TransactionType
                        switch transaction.type {
                        case .borrowed, .borrowedReturn:
                            regularTransactionType = .income
                        case .lent, .lentReturn:
                            regularTransactionType = .expense
                        }
                        
                        let regularTransaction = Transaction(
                            id: transaction.id, // Use same ID to link them
                            title: transactionTitle,
                            category: "Debt",
                            amount: transaction.amount,
                            date: transaction.date,
                            type: regularTransactionType,
                            accountId: transaction.accountId,
                            toAccountId: nil,
                            currency: transaction.currency
                        )
                        
                        if isUpdate {
                            // Update existing transaction if it exists
                            if transactionManager.getTransaction(id: transaction.id) != nil {
                                transactionManager.updateTransaction(regularTransaction)
                            } else {
                                // If transaction doesn't exist, create it
                                transactionManager.addTransaction(regularTransaction)
                            }
                        } else {
                            // Create new transaction only if it doesn't already exist (prevent duplication)
                            if transactionManager.getTransaction(id: transaction.id) == nil {
                                transactionManager.addTransaction(regularTransaction)
                            }
                        }
                        
                        showAddTransaction = false
                        editingTransaction = nil
                    },
                    onCancel: {
                        showAddTransaction = false
                        editingTransaction = nil
                    }
                )
                .environmentObject(settings)
                .environmentObject(transactionManager)
            }
            .alert(String(localized: "Delete Contact", comment: "Delete contact alert title"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    let contactToDelete = currentContact ?? contact
                    // Delete transactions for all debt transactions before deleting contact
                    // Balance is reverted automatically by DeleteTransactionUseCase
                    let transactionsToRevert = debtManager.getTransactions(for: contactToDelete.id)
                    for transaction in transactionsToRevert {
                        // Delete corresponding Transaction
                        if let transactionToDelete = transactionManager.getTransaction(id: transaction.id) {
                            transactionManager.deleteTransaction(transactionToDelete)
                        }
                    }
                    debtManager.deleteContact(contactToDelete)
                    dismiss()
                }
            } message: {
                Text(String(localized: "Are you sure you want to delete this contact? All associated transaction history will be permanently deleted.", comment: "Delete contact confirmation"))
            }
            .alert(String(localized: "Delete Transaction", comment: "Delete transaction alert title"), isPresented: $showDeleteTransactionAlert) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
                    transactionToDelete = nil
                }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    if let transaction = transactionToDelete {
                        // Delete corresponding Transaction
                        // Balance is reverted automatically by DeleteTransactionUseCase
                        if let transactionToDelete = transactionManager.getTransaction(id: transaction.id) {
                            transactionManager.deleteTransaction(transactionToDelete)
                        }
                        debtManager.deleteTransaction(transaction)
                        transactionToDelete = nil
                    }
                }
            } message: {
                if let transaction = transactionToDelete {
                    Text(String(localized: "Are you sure you want to delete this %@ transaction of %@?", comment: "Delete transaction confirmation").replacingOccurrences(of: "%@", with: transaction.type.title.lowercased()).replacingOccurrences(of: "%@", with: currencyString(transaction.amount, code: settings.currency), options: [], range: nil))
                } else {
                    Text(String(localized: "Are you sure you want to delete this transaction?", comment: "Delete transaction confirmation simple"))
                }
            }
        }
    }
}

struct EditContactView: View {
    let contact: Contact
    @ObservedObject var debtManager: DebtManager
    let onSave: (Contact) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String
    
    init(contact: Contact, debtManager: DebtManager, onSave: @escaping (Contact) -> Void, onCancel: @escaping () -> Void) {
        self.contact = contact
        self.debtManager = debtManager
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: contact.name)
        _selectedColor = State(initialValue: contact.avatarColor)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Details") {
                    TextField("Name", text: $name)
                    Picker("Avatar Color", selection: $selectedColor) {
                        ForEach(["blue", "purple", "pink", "orange", "indigo", "teal", "cyan", "mint"], id: \.self) { colorName in
                            HStack {
                                Circle()
                                    .fill(Contact(name: "", avatarColor: colorName).color)
                                    .frame(width: 20, height: 20)
                                Text(colorName.capitalized)
                            }
                            .tag(colorName)
                        }
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = Contact(id: contact.id, name: name.trimmingCharacters(in: .whitespaces), avatarColor: selectedColor)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TransactionHistoryRow: View {
    @EnvironmentObject var settings: AppSettings
    let transaction: DebtTransaction
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(transaction.type.direction.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: transaction.type.direction == .owedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(transaction.type.direction.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.type.isReturn ? String(localized: "Returned", comment: "Returned debt") : transaction.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let note = transaction.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(transaction.amount, code: settings.currency))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(transaction.type.direction.color)
                    if transaction.isSettled {
                        Text(String(localized: "Settled", comment: "Settled status"))
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(16)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

