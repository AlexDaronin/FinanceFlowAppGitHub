//
//  ContentView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var debtManager = DebtManager()
    @State private var sharedTransactions = Transaction.sample
    @State private var sharedAccounts = Account.sample
    
    private var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var body: some View {
        TabView {
            DashboardView(transactions: $sharedTransactions, accounts: $sharedAccounts)
                .tabItem {
                    Label("", systemImage: "square.grid.2x2")
                }
            
            TransactionsView(transactions: $sharedTransactions, accounts: $sharedAccounts)
                .tabItem {
                    Label("", systemImage: "list.bullet")
                }
            
            StatisticsView()
                .tabItem {
                    Label("", systemImage: "chart.bar")
                }
            
            AIChatView()
                .tabItem {
                    Label("", systemImage: "sparkles")
                }
            
            SettingsView()
                .tabItem {
                    Label("", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(colorScheme)
        .environmentObject(settings)
        .environmentObject(debtManager)
        .environment(\.locale, settings.locale)
        .onAppear {
            // Hide tab bar labels to make it icon-only
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            // Remove title text completely
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
            appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 100)
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

// DashboardView is defined in DashboardView.swift
// StatisticsView is defined in StatisticsView.swift
// AIChatView is defined in AIChatView.swift

struct CreditsLoansView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var credits = Credit.sample
    @State private var selectedDate = Date()
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    
    private var totalRemaining: Double {
        credits.map(\.remaining).reduce(0, +)
    }
    
    private var activeCreditsCount: Int {
        credits.filter { $0.remaining > 0 }.count
    }
    
    private var categories: [String] {
        Array(Set(Transaction.sample.map(\.category))).sorted()
    }
    
    private let actionOptions: [ActionMenuOption] = ActionMenuOption.transactions
    
    private var datePickerDays: [(day: String, date: Date, dayNumber: Int)] {
        let calendar = Calendar.current
        let today = Date()
        var days: [(String, Date, Int)] = []
        
        for i in -3...3 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let dayName = dayFormatter.string(from: date)
                let dayNumber = calendar.component(.day, from: date)
                days.append((dayName, date, dayNumber))
            }
        }
        return days
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credits & Loans")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Track your debts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Summary Card
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currencyString(totalRemaining, code: settings.currency))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.caption2)
                                Text("~ \(activeCreditsCount) active credits")
                                    .font(.caption2)
                            }
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
                        
                        // Date Picker
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(datePickerDays, id: \.date) { dayInfo in
                                        VStack(spacing: 8) {
                                            Text(dayInfo.day)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("\(dayInfo.dayNumber)")
                                                .font(.headline)
                                                .foregroundStyle(selectedDate.isSameDay(as: dayInfo.date) ? .white : .primary)
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    Circle()
                                                        .fill(selectedDate.isSameDay(as: dayInfo.date) ? Color.accentColor : Color.customCardBackground)
                                                )
                                        }
                                        .onTapGesture {
                                            selectedDate = dayInfo.date
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Credits List
                        VStack(spacing: 16) {
                            ForEach(credits) { credit in
                                CreditCard(credit: credit)
                            }
                        }
                    }
                    .padding()
                }
                
                // Floating Action Button (same as DashboardView)
                floatingActionButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTransactionForm) {
                TransactionFormView(
                    draft: $draftTransaction,
                    mode: currentFormMode,
                    categories: categories,
                    accounts: Account.sample,
                    onSave: { draft in
                        handleSave(draft)
                    },
                    onCancel: {
                        showTransactionForm = false
                    },
                    onDelete: nil
                )
                .id(currentFormMode) // Force recreation when mode changes
            }
        }
    }
    
    private var floatingActionButton: some View {
        ZStack {
            if showActionMenu {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showActionMenu = false
                        }
                    }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        if showActionMenu {
                            ForEach(actionOptions) { option in
                                Button {
                                    startAddingTransaction(for: option.type)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(option.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                        Image(systemName: option.icon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .frame(width: 52, height: 52)
                                            .background(
                                                LinearGradient(
                                                    colors: [option.tint.opacity(0.9), option.tint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .scaleEffect(showActionMenu ? 1 : 0.7, anchor: .trailing)
                            }
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showActionMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showActionMenu ? "xmark" : "plus")
                                .font(.title2.weight(.bold))
                                .rotationEffect(.degrees(showActionMenu ? 45 : 0))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func startAddingTransaction(for type: TransactionType) {
        currentFormMode = .add(type)
        draftTransaction = TransactionDraft(type: type, currency: settings.currency)
        showTransactionForm = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showActionMenu = false
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        // In a real app, this would save to a shared data store
        showTransactionForm = false
    }
}

struct DebtsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var debtManager: DebtManager
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debts")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Track money between people")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // To Receive section
                        debtGroupSection(
                            title: "To Receive",
                            contacts: contactsOwedToMe,
                            total: totalOwedToMe,
                            color: .green,
                            isExpanded: $owedToMeExpanded
                        )
                        
                        // To Pay section
                        debtGroupSection(
                            title: "To Pay",
                            contacts: contactsIOwe,
                            total: totalIOwe,
                            color: .red,
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
            }
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(debtManager: debtManager, contact: contact)
                    .environmentObject(settings)
            }
        }
    }
    
    private func debtGroupSection(
        title: String,
        contacts: [(contact: Contact, balance: Double)],
        total: Double,
        color: Color,
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
                    // Color indicator
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 8, height: 8)
                    
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Total amount (bolder and more impactful)
                    Text(currencyString(total, code: settings.currency))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                    
                    // Count badge
                    if !contacts.isEmpty {
                        Text("\(contacts.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .clipShape(Capsule())
                    }
                    
                    // Chevron with smooth rotation
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
                        ContactCard(contact: item.contact, balance: item.balance, color: color, latestTransaction: latestTransaction) {
                            selectedContact = item.contact
                        }
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
            Text("No debts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    selectedContact = nil
                    showDebtForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100)
            }
        }
        .ignoresSafeArea()
    }
    
    private func handleSave(contact: Contact, transaction: DebtTransaction) {
        // Save or update contact
        if debtManager.contacts.contains(where: { $0.id == contact.id }) {
            debtManager.updateContact(contact)
        } else {
            debtManager.addContact(contact)
        }
        
        // Save transaction
        if debtManager.transactions.contains(where: { $0.id == transaction.id }) {
            debtManager.updateTransaction(transaction)
        } else {
            debtManager.addTransaction(transaction)
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
    let latestTransaction: DebtTransaction?
    
    init(contact: Contact, balance: Double, color: Color, latestTransaction: DebtTransaction? = nil, onTap: @escaping () -> Void) {
        self.contact = contact
        self.balance = balance
        self.color = color
        self.latestTransaction = latestTransaction
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // Avatar with initials
                ZStack {
                    Circle()
                        .fill(contact.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(contact.color)
                }
                
                // Name
                Text(contact.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Amount and date
                VStack(alignment: .trailing, spacing: 6) {
                    Text(currencyString(abs(balance), code: settings.currency))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                    
                    HStack(spacing: 4) {
                        if let transaction = latestTransaction {
                            Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                            
                            if let note = transaction.note, !note.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.primary.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct DebtFormView: View {
    let contact: Contact?
    let debtManager: DebtManager
    let onSave: (Contact, DebtTransaction) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @State private var selectedContact: Contact?
    @State private var contactName: String = ""
    @State private var showContactPicker = false
    @State private var showCreateContact = false
    @State private var transactionType: DebtTransactionType = .lent
    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var editingTransaction: DebtTransaction?
    
    @FocusState private var isAmountFocused: Bool
    
    init(contact: Contact? = nil, debtManager: DebtManager, editingTransaction: DebtTransaction? = nil, onSave: @escaping (Contact, DebtTransaction) -> Void, onCancel: @escaping () -> Void) {
        self.contact = contact
        self.debtManager = debtManager
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedContact = State(initialValue: contact)
        _editingTransaction = State(initialValue: editingTransaction)
        if let contact = contact {
            _contactName = State(initialValue: contact.name)
        }
        if let transaction = editingTransaction {
            _amount = State(initialValue: transaction.amount)
            _date = State(initialValue: transaction.date)
            _note = State(initialValue: transaction.note ?? "")
            _transactionType = State(initialValue: transaction.type)
            if let contact = debtManager.getContact(id: transaction.contactId) {
                _selectedContact = State(initialValue: contact)
                _contactName = State(initialValue: contact.name)
            }
        }
    }
    
    // MARK: - Theme Color
    private var themeColor: Color {
        transactionType == .lent ? .green : .red
    }
    
    // MARK: - Sign Symbol
    private var signSymbol: String {
        transactionType == .lent ? "+" : "-"
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
                            // Contact Row
                            DebtContactRow(
                                contact: selectedContact,
                                onTap: { showContactPicker = true }
                            )
                            
                            // Date Field
                            TransactionDateRow(
                                icon: "calendar",
                                title: "Date",
                                date: $date
                            )
                            
                            // Note Field
                            TransactionFormRow(
                                icon: "text.alignleft",
                                title: "Note",
                                value: $note,
                                placeholder: "Add a note (optional)"
                            )
                        }
                        .padding(.horizontal)
                        
                        // Save Button
                        Button {
                            handleSave()
                        } label: {
                            Text("Save")
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
            }
            .navigationTitle(editingTransaction == nil ? "Add Debt" : "Edit Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView(
                    contacts: debtManager.contacts,
                    selectedContact: $selectedContact,
                    onSelect: { contact in
                        selectedContact = contact
                        contactName = contact.name
                        showContactPicker = false
                    },
                    onCreateNew: {
                        showContactPicker = false
                        showCreateContact = true
                    }
                )
            }
            .sheet(isPresented: $showCreateContact) {
                CreateContactView(
                    contactName: $contactName,
                    onSave: { name in
                        let newContact = Contact(name: name, avatarColor: Contact.generateColor(for: name))
                        selectedContact = newContact
                        contactName = name
                        showCreateContact = false
                    },
                    onCancel: {
                        showCreateContact = false
                    }
                )
            }
            .onAppear {
                // Initialize amount text from amount
                if amount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(amount)
                }
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
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
        (selectedContact != nil || !contactName.trimmingCharacters(in: .whitespaces).isEmpty) && amount > 0
    }
    
    private func handleSave() {
        let finalContact: Contact
        if let existing = selectedContact, debtManager.contacts.contains(where: { $0.id == existing.id }) {
            finalContact = existing
        } else if let existing = selectedContact {
            finalContact = existing
        } else {
            finalContact = Contact(name: contactName.trimmingCharacters(in: .whitespaces), avatarColor: Contact.generateColor(for: contactName))
        }
        
        let transaction = DebtTransaction(
            id: editingTransaction?.id ?? UUID(),
            contactId: finalContact.id,
            amount: amount,
            type: transactionType,
            date: date,
            note: note.isEmpty ? nil : note,
            isSettled: editingTransaction?.isSettled ?? false
        )
        
        onSave(finalContact, transaction)
        dismiss()
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach([DebtTransactionType.lent, DebtTransactionType.borrowed]) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        transactionType = type
                    }
                } label: {
                    Text(type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transactionType == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(transactionType == type ? type.direction.color : Color.clear)
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
                
                // Icon/Sign for transaction type
                Text(signSymbol)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
                
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
        // Remove any non-numeric characters except decimal point
        let cleaned = newValue.filter { $0.isNumber || $0 == "." }
        
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
}

// MARK: - Debt Contact Row Component
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
                    
                    Text("Contact")
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
                    
                    Text("Contact")
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("Select or create contact")
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

struct PaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    let payment: PlannedPayment
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Payment info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(payment.title)
                            .font(.title2.weight(.bold))
                        
                        Text(payment.category ?? "General")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if payment.type == .loan {
                        // Loan details
                        VStack(alignment: .leading, spacing: 16) {
                            if let total = payment.totalLoanAmount, let remaining = payment.remainingBalance {
                                DetailRow(label: "Total Amount", value: currencyString(total, code: settings.currency))
                                DetailRow(label: "Remaining Balance", value: currencyString(remaining, code: settings.currency))
                                DetailRow(label: "Progress", value: "\(Int(payment.progress))%")
                                
                                if let months = payment.monthsRemaining {
                                    DetailRow(label: "Months Remaining", value: "\(months)")
                                }
                            }
                            
                            if let rate = payment.interestRate {
                                DetailRow(label: "Interest Rate", value: String(format: "%.2f%%", rate))
                            }
                        }
                        .padding()
                        .background(Color.customCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    
                    DetailRow(label: "Monthly Payment", value: currencyString(payment.amount, code: settings.currency))
                    DetailRow(label: "Next Payment", value: shortDate(payment.date))
                    DetailRow(label: "Account", value: payment.accountName)
                }
                .padding()
            }
            .background(Color.customBackground)
            .navigationTitle("Payment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct AddPaymentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    
    let paymentType: PlannedPaymentType
    let existingPayment: PlannedPayment?
    let onSave: (PlannedPayment) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var amount: Double = 0
    @State private var date: Date = Date()
    @State private var accountName: String = "Main Card"
    @State private var category: String? = nil
    
    // Loan-specific fields
    @State private var totalLoanAmount: Double? = nil
    @State private var remainingBalance: Double? = nil
    @State private var startDate: Date? = nil
    @State private var interestRate: Double? = nil
    
    init(
        paymentType: PlannedPaymentType,
        existingPayment: PlannedPayment? = nil,
        onSave: @escaping (PlannedPayment) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.paymentType = paymentType
        self.existingPayment = existingPayment
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize from existing payment if editing
        if let existing = existingPayment {
            _title = State(initialValue: existing.title)
            _amount = State(initialValue: existing.amount)
            _date = State(initialValue: existing.date)
            _accountName = State(initialValue: existing.accountName)
            _category = State(initialValue: existing.category)
            _totalLoanAmount = State(initialValue: existing.totalLoanAmount)
            _remainingBalance = State(initialValue: existing.remainingBalance)
            _startDate = State(initialValue: existing.startDate)
            _interestRate = State(initialValue: existing.interestRate)
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }
    
    private var isValidLoan: Bool {
        isValid && totalLoanAmount != nil && totalLoanAmount! > 0 && remainingBalance != nil && remainingBalance! >= 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("Monthly Payment")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    DatePicker("Next Payment Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Account", selection: $accountName) {
                        Text("Main Card").tag("Main Card")
                        Text("Savings").tag("Savings")
                        Text("Credit Card").tag("Credit Card")
                    }
                    
                    Picker("Category", selection: Binding(
                        get: { category ?? "General" },
                        set: { category = $0 == "General" ? nil : $0 }
                    )) {
                        Text("General").tag("General")
                        Text("Entertainment").tag("Entertainment")
                        Text("Housing").tag("Housing")
                        Text("Utilities").tag("Utilities")
                        Text("Debt").tag("Debt")
                    }
                }
                
                if paymentType == .loan {
                    Section("Loan Details") {
                        HStack {
                            Text("Total Loan Amount")
                            Spacer()
                            TextField("0", value: $totalLoanAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Remaining Balance")
                            Spacer()
                            TextField("0", value: $remainingBalance, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        
                        DatePicker("Start Date", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ), displayedComponents: .date)
                        
                        HStack {
                            Text("Interest Rate (%)")
                            Spacer()
                            TextField("Optional", value: $interestRate, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(existingPayment != nil ? (paymentType == .subscription ? "Edit Subscription" : "Edit \(paymentType.label)") : (paymentType == .subscription ? "Add Subscription" : "Add \(paymentType.label)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let payment = PlannedPayment(
                            id: existingPayment?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespaces),
                            amount: amount,
                            date: date,
                            status: existingPayment?.status ?? .upcoming,
                            accountName: accountName,
                            category: category,
                            type: paymentType,
                            totalLoanAmount: totalLoanAmount,
                            remainingBalance: remainingBalance,
                            startDate: startDate,
                            interestRate: interestRate
                        )
                        onSave(payment)
                    }
                    .disabled(paymentType == .loan ? !isValidLoan : !isValid)
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        NavigationStack {
            Form {
                // General settings - most commonly used, ordered by importance
                Section(String(localized: "General", comment: "General settings section")) {
                    // Language first for accessibility
                    Picker(String(localized: "Language", comment: "Language picker"), selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    
                    // Theme for visual preferences
                    Picker(String(localized: "Theme", comment: "Theme picker"), selection: $settings.theme) {
                        ForEach(ThemeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    
                    // Currency for financial display
                    Picker(String(localized: "Currency", comment: "Currency picker"), selection: $settings.currency) {
                        ForEach(["USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "INR", "PLN", "RUB", "BRL", "MXN", "KRW", "SGD", "HKD", "NZD", "SEK", "NOK", "DKK"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    
                    // Start day for monthly calculations
                    NavigationLink {
                        StartDaySelectionView(selectedDay: $settings.startDay)
                    } label: {
                        HStack {
                            Text("Start day of month", comment: "Start day of month label")
                            Spacer()
                            Text("\(settings.startDay)\(daySuffix(settings.startDay))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Accounts & Categories - data management
                Section(String(localized: "Accounts & Categories", comment: "Accounts & Categories section")) {
                    NavigationLink(String(localized: "Manage accounts", comment: "Manage accounts link")) {
                        Text("Accounts editor coming soon.", comment: "Accounts editor coming soon message")
                            .foregroundStyle(.secondary)
                    }
                    
                    NavigationLink(String(localized: "Manage categories", comment: "Manage categories link")) {
                        CategoryManagementView()
                            .environmentObject(settings)
                    }
                    
                    Toggle(String(localized: "Include cash in totals", comment: "Include cash toggle"), isOn: $settings.includeCashInTotals)
                }
                
                // Notifications - all notification preferences together
                Section(String(localized: "Notifications", comment: "Notifications section")) {
                    Toggle(String(localized: "Payment reminders", comment: "Payment reminders toggle"), isOn: $settings.notificationsEnabled)
                    Toggle(String(localized: "Subscription alerts", comment: "Subscription alerts toggle"), isOn: $settings.subscriptionAlerts)
                }
                
                // Premium - subscription management
                Section(String(localized: "Premium", comment: "Premium section")) {
                    Button(role: settings.premiumEnabled ? .destructive : .none) {
                        settings.premiumEnabled.toggle()
                    } label: {
                        Text(settings.premiumEnabled ? String(localized: "Cancel subscription", comment: "Cancel subscription button") : String(localized: "Start premium trial", comment: "Start premium trial button"))
                            .foregroundStyle(settings.premiumEnabled ? .red : .accentColor)
                    }
                }
                
                // Data & Backup - advanced features at the end
                Section(String(localized: "Data & Backup", comment: "Data & Backup section")) {
                    Button(String(localized: "Export local backup", comment: "Export backup button")) {
                        // TODO: integrate backup flow
                    }
                    Button(String(localized: "Restore from backup", comment: "Restore backup button")) {
                        // TODO: integrate restore flow
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(Text("Settings", comment: "Settings view title"))
        }
    }
}
struct TransactionsView: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @State private var plannedPayments = PlannedPayment.sample
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedType: TransactionType?
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    @State private var scrollOffset: CGFloat = 0
    @State private var showPlannedPayments = false
    @State private var selectedTab: TransactionTab = .past
    
    private var categories: [String] {
        Array(Set(transactions.map(\.category))).sorted()
    }
    
    private var upcomingPayments: [PlannedPayment] {
        plannedPayments
            .filter { $0.status == .upcoming && $0.date >= Date() }
            .sorted { $0.date < $1.date }
    }
    
    private var missedPayments: [PlannedPayment] {
        plannedPayments
            .filter { $0.status == .past || ($0.date < Date() && $0.status == .upcoming) }
            .sorted { $0.date < $1.date }
    }
    
    private var filteredTransactions: [Transaction] {
        transactions
            .filter { transaction in
                let matchesSearch = searchText.isEmpty ||
                transaction.title.localizedCaseInsensitiveContains(searchText) ||
                transaction.category.localizedCaseInsensitiveContains(searchText) ||
                transaction.accountName.localizedCaseInsensitiveContains(searchText)
                
                let matchesCategory = selectedCategory == nil || transaction.category == selectedCategory
                let matchesType = selectedType == nil || transaction.type == selectedType
                return matchesSearch && matchesCategory && matchesType
            }
            .filter { $0.date <= Date() }
            .sorted { $0.date > $1.date }
    }
    
    // Group transactions by day
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }
    
    // Group planned payments by day
    private var groupedUpcomingPayments: [(date: Date, payments: [PlannedPayment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: upcomingPayments) { payment in
            calendar.startOfDay(for: payment.date)
        }
        return grouped
            .map { (date: $0.key, payments: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
    
    // Group missed payments by day
    private var groupedMissedPayments: [(date: Date, payments: [PlannedPayment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: missedPayments) { payment in
            calendar.startOfDay(for: payment.date)
        }
        return grouped
            .map { (date: $0.key, payments: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }
    
    private let actionOptions: [ActionMenuOption] = ActionMenuOption.transactions
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Tab Buttons
                            tabButtons
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 16)
                            
                            // Planned Payments Section (hidden by default, appears when scrolling up from top)
                            // Only show for past tab
                            if selectedTab == .past && !upcomingPayments.isEmpty {
                                plannedPaymentsSection
                                    .opacity(showPlannedPayments ? 1 : 0)
                                    .frame(height: showPlannedPayments ? nil : 0, alignment: .top)
                                    .clipped()
                                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showPlannedPayments)
                            }
                            
                            // Main Content List
                            VStack(spacing: 0) {
                                if selectedCategory != nil {
                                    resetFilterChip
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .padding(.bottom, 8)
                                }
                                
                                // Show different content based on selected tab
                                switch selectedTab {
                                case .past:
                                    if filteredTransactions.isEmpty {
                                        emptyTransactionsState
                                            .padding()
                                    } else {
                                        ForEach(Array(groupedTransactions.enumerated()), id: \.element.date) { index, dayGroup in
                                            VStack(alignment: .leading, spacing: 12) {
                                                // Day Header
                                                dayHeader(for: dayGroup.date)
                                                    .padding(.horizontal, 20)
                                                    .padding(.top, index == 0 ? 8 : 16)
                                                    .padding(.bottom, 8)
                                                
                                                // Transactions for this day - using ForEach with swipe actions
                                                ForEach(dayGroup.transactions) { transaction in
                                                    Button {
                                                        startEditing(transaction)
                                                    } label: {
                                                        TransactionRow(transaction: transaction)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button(role: .destructive) {
                                                            deleteTransaction(transaction)
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                                    .id(transaction.id)
                                                    .padding(.bottom, 8)
                                                }
                                            }
                                        }
                                    }
                                case .planned:
                                    if upcomingPayments.isEmpty {
                                        emptyPlannedState
                                            .padding()
                                    } else {
                                        ForEach(Array(groupedUpcomingPayments.enumerated()), id: \.element.date) { index, dayGroup in
                                            VStack(alignment: .leading, spacing: 12) {
                                                // Day Header
                                                dayHeader(for: dayGroup.date)
                                                    .padding(.horizontal, 20)
                                                    .padding(.top, index == 0 ? 8 : 16)
                                                    .padding(.bottom, 8)
                                                
                                                // Payments for this day
                                                ForEach(dayGroup.payments) { payment in
                                                    PlannedPaymentRow(payment: payment)
                                                        .padding(.bottom, 8)
                                                }
                                            }
                                        }
                                    }
                                case .missed:
                                    if missedPayments.isEmpty {
                                        emptyMissedState
                                            .padding()
                                    } else {
                                        ForEach(Array(groupedMissedPayments.enumerated()), id: \.element.date) { index, dayGroup in
                                            VStack(alignment: .leading, spacing: 12) {
                                                // Day Header
                                                dayHeader(for: dayGroup.date)
                                                    .padding(.horizontal, 20)
                                                    .padding(.top, index == 0 ? 8 : 16)
                                                    .padding(.bottom, 8)
                                                
                                                // Payments for this day
                                                ForEach(dayGroup.payments) { payment in
                                                    PlannedPaymentRow(payment: payment)
                                                        .padding(.bottom, 8)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Only show planned payments section when on past tab
                        guard selectedTab == .past else {
                            if showPlannedPayments {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    showPlannedPayments = false
                                }
                            }
                            return
                        }
                        
                        // Show when scrolling up from top
                        // Positive offset indicates bounce/overscroll at top (scrolling up)
                        // Negative offset means scrolling down
                        let threshold: CGFloat = 12
                        let shouldShow = value > threshold
                        
                        if shouldShow != showPlannedPayments {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showPlannedPayments = shouldShow
                            }
                        }
                        scrollOffset = value
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        // Hide planned payments section when switching away from past tab
                        if newValue != .past && showPlannedPayments {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showPlannedPayments = false
                            }
                        }
                    }
                }
                .background(Color.customBackground)
                .navigationTitle(Text("Transactions", comment: "Transactions view title"))
                .searchable(text: $searchText, prompt: Text("Search transactions", comment: "Search transactions placeholder"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if selectedCategory != nil {
                            Button(String(localized: "Reset", comment: "Reset filter button")) {
                                withAnimation(.easeInOut) {
                                    selectedCategory = nil
                                }
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        categoryMenu
                        typeMenu
                    }
                }
                
                floatingActionButton
            }
            .sheet(isPresented: $showTransactionForm) {
                TransactionFormView(
                    draft: $draftTransaction,
                    mode: currentFormMode,
                    categories: categories,
                    accounts: Account.sample,
                    onSave: { draft in
                        handleSave(draft)
                    },
                    onCancel: {
                        showTransactionForm = false
                    },
                    onDelete: { id in
                        if let transaction = transactions.first(where: { $0.id == id }) {
                            deleteTransaction(transaction)
                        }
                        showTransactionForm = false
                    }
                )
                .id(currentFormMode) // Force recreation when mode changes
            }
        }
    }
    
    private var tabButtons: some View {
        HStack(spacing: 12) {
            // Past/Today Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .past
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.caption)
                    Text("Today", comment: "Today tab")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(selectedTab == .past ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    selectedTab == .past ? Color.accentColor : Color.customCardBackground
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selectedTab == .past ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Missed Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .missed
                }
            } label: {
                Text("Missed", comment: "Missed tab")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedTab == .missed ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == .missed ? Color.orange : Color.customCardBackground
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == .missed ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            // Future Tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .planned
                }
            } label: {
                Text("Future", comment: "Future tab")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedTab == .planned ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == .planned ? Color.blue : Color.customCardBackground
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == .planned ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    private var plannedPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Upcoming Payments", comment: "Upcoming payments header")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(upcomingPayments.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.customSecondaryBackground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Planned Payments List
            VStack(spacing: 12) {
                ForEach(upcomingPayments) { payment in
                    PlannedPaymentRow(payment: payment)
                }
            }
            .padding(.bottom, 20)
            
            // Separator
            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .background(Color.customBackground)
    }
    
    private var categoryMenu: some View {
        Menu {
            Button(String(localized: "All Categories", comment: "All categories filter")) {
                selectedCategory = nil
            }
            Divider()
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                }
            }
        } label: {
            Label(selectedCategory ?? String(localized: "Categories", comment: "Categories menu label"), systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private var typeMenu: some View {
        Menu {
            Button(String(localized: "All Types", comment: "All types filter")) {
                selectedType = nil
            }
            Divider()
            ForEach(TransactionType.allCases) { type in
                Button(type.title) {
                    selectedType = type
                }
            }
        } label: {
            Label(selectedType?.title ?? String(localized: "Types", comment: "Types menu label"), systemImage: "slider.horizontal.3")
        }
    }
    
    
    private var resetFilterChip: some View {
        Button {
            withAnimation(.spring) {
                selectedCategory = nil
            }
        } label: {
            HStack {
                Text("\(String(localized: "Category:", comment: "Category filter prefix")) \(selectedCategory ?? "")")
                Spacer()
                Image(systemName: "xmark.circle.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var floatingActionButton: some View {
        ZStack {
            if showActionMenu {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showActionMenu = false
                        }
                    }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        if showActionMenu {
                            ForEach(actionOptions) { option in
                                Button {
                                    startAddingTransaction(for: option.type)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(option.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                        Image(systemName: option.icon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .frame(width: 52, height: 52)
                                            .background(
                                                LinearGradient(
                                                    colors: [option.tint.opacity(0.9), option.tint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .scaleEffect(showActionMenu ? 1 : 0.7, anchor: .trailing)
                            }
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showActionMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showActionMenu ? "xmark" : "plus")
                                .font(.title2.weight(.bold))
                                .rotationEffect(.degrees(showActionMenu ? 45 : 0))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var emptyTransactionsState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No results", comment: "No results empty state")
                .font(.headline)
            Text("Try changing your search or filters.", comment: "No results suggestion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
    
    private var emptyPlannedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.blue.opacity(0.6))
            Text("No upcoming payments", comment: "No upcoming payments empty state")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("You don't have any planned payments scheduled.", comment: "No planned payments message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyMissedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))
            Text("No missed payments", comment: "No missed payments empty state")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("All your payments are up to date.", comment: "All payments up to date message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func dayHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isYesterday = calendar.isDateInYesterday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)
        
        let dateString: String
        if isToday {
            dateString = String(localized: "Today", comment: "Today date header")
        } else if isYesterday {
            dateString = String(localized: "Yesterday", comment: "Yesterday date header")
        } else if isTomorrow {
            dateString = String(localized: "Tomorrow", comment: "Tomorrow date header")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            dateString = formatter.string(from: date)
        }
        
        return HStack {
            Text(dateString)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private func startAddingTransaction(for type: TransactionType) {
        currentFormMode = .add(type)
        draftTransaction = TransactionDraft(type: type, currency: settings.currency)
        showTransactionForm = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showActionMenu = false
        }
    }
    
    private func startEditing(_ transaction: Transaction) {
        // Reset sheet state first to ensure clean state
        if showTransactionForm {
            showTransactionForm = false
            // Wait for sheet to close before opening with new mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.currentFormMode = .edit(transaction.id)
                self.draftTransaction = TransactionDraft(transaction: transaction)
                self.showTransactionForm = true
            }
        } else {
            // Set the new mode and draft
            currentFormMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = true
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        let oldTransaction: Transaction?
        
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactions.insert(newTransaction, at: 0)
            oldTransaction = nil
        case .edit(let id):
            oldTransaction = transactions.first(where: { $0.id == id })
            let updated = draft.toTransaction(existingId: id)
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions[index] = updated
            }
        }
        
        // Update account balances using draft (which has toAccountName for transfers)
        updateAccountBalances(oldTransaction: oldTransaction, newDraft: draft)
        
        showTransactionForm = false
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        // Revert account balance changes for deleted transaction
        updateAccountBalances(oldTransaction: transaction, newDraft: nil)
    }
    
    private func updateAccountBalances(oldTransaction: Transaction?, newDraft: TransactionDraft?) {
        // Helper function to calculate balance change for a transaction
        func balanceChange(for transaction: Transaction) -> Double {
            switch transaction.type {
            case .income:
                return transaction.amount
            case .expense:
                return -transaction.amount
            case .transfer:
                // Transfers don't change total balance, but move money between accounts
                return 0
            case .debt:
                // Debt transactions don't affect account balance
                return 0
            }
        }
        
        // Revert old transaction's effect
        if let old = oldTransaction {
            if let accountIndex = accounts.firstIndex(where: { $0.name == old.accountName }) {
                accounts[accountIndex].balance -= balanceChange(for: old)
            }
            
            // Handle transfers - revert from both accounts
            if old.type == .transfer, let toAccountName = old.toAccountName,
               let toAccountIndex = accounts.firstIndex(where: { $0.name == toAccountName }) {
                accounts[toAccountIndex].balance += old.amount // Add back to 'to' account
            }
        }
        
        // Apply new transaction's effect using draft (which has toAccountName)
        if let draft = newDraft {
            let balanceChange = draft.type == .income ? draft.amount : (draft.type == .expense ? -draft.amount : 0)
            
            if draft.type == .transfer, let toAccountName = draft.toAccountName {
                // Transfer: subtract from fromAccount, add to toAccount
                if let fromAccountIndex = accounts.firstIndex(where: { $0.name == draft.accountName }) {
                    accounts[fromAccountIndex].balance -= draft.amount
                }
                if let toAccountIndex = accounts.firstIndex(where: { $0.name == toAccountName }) {
                    accounts[toAccountIndex].balance += draft.amount
                }
            } else if draft.type != .debt {
                // Income or Expense: update the account balance
                if let accountIndex = accounts.firstIndex(where: { $0.name == draft.accountName }) {
                    accounts[accountIndex].balance += balanceChange
                }
            }
            // Debt transactions don't affect account balance
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    @EnvironmentObject var settings: AppSettings
    
    private var categoryIcon: String {
        if let category = settings.categories.first(where: { $0.name == transaction.category }) {
            return category.iconName
        }
        return transaction.type.iconName
    }
    
    private var categoryColor: Color {
        if let category = settings.categories.first(where: { $0.name == transaction.category }) {
            return category.color
        }
        return transaction.type.color
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .foregroundStyle(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.subheadline.weight(.semibold))
                Text(transaction.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(transaction.date.formatted(.dateTime.day().month(.abbreviated))) • \(transaction.accountName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.displayAmount())
                .font(.headline)
                .foregroundStyle(transaction.type.color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PlannedPaymentRow: View {
    let payment: PlannedPayment
    @EnvironmentObject var settings: AppSettings
    
    private var categoryIcon: String {
        if let categoryName = payment.category,
           let category = settings.categories.first(where: { $0.name == categoryName }) {
            return category.iconName
        }
        return "calendar"
    }
    
    private var iconColor: Color {
        if let categoryName = payment.category,
           let category = settings.categories.first(where: { $0.name == categoryName }) {
            return category.color
        }
        return payment.status == .past || payment.date < Date() ? .orange : .blue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.title)
                    .font(.subheadline.weight(.semibold))
                Text(payment.category ?? "General")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(payment.date.formatted(.dateTime.day().month(.abbreviated))) • \(payment.accountName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(currencyString(payment.amount, code: settings.currency))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(payment.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TransactionFormView: View {
    @Binding var draft: TransactionDraft
    let mode: TransactionFormMode
    let categories: [String]
    let accounts: [Account]
    let onSave: (TransactionDraft) -> Void
    let onCancel: () -> Void
    let onDelete: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var debtManager: DebtManager
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showToAccountPicker = false
    @State private var showContactPicker = false
    @State private var selectedContact: Contact?
    @State private var debtTransactionType: DebtTransactionType = .lent
    @State private var amountText: String = ""
    @State private var repeatOption: RepeatOption = .never
    @State private var saveToPlannedPayments: Bool = false
    @State private var showDeleteAlert = false
    
    @FocusState private var isAmountFocused: Bool
    
    // Computed property to check if we're in edit mode
    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }
    
    enum RepeatOption: String, CaseIterable {
        case never = "Never"
        case monthly = "Every Month"
        case yearly = "Every Year"
        
        var localizedTitle: String {
            switch self {
            case .never:
                return String(localized: "Never", comment: "Never repeat option")
            case .monthly:
                return String(localized: "Every Month", comment: "Every month repeat option")
            case .yearly:
                return String(localized: "Every Year", comment: "Every year repeat option")
            }
        }
    }
    
    private var availableCategories: [Category] {
        var filtered = settings.categories
        
        // Filter by category type based on transaction type
        switch draft.type {
        case .income:
            filtered = filtered.filter { $0.type == .income }
        case .expense:
            filtered = filtered.filter { $0.type == .expense }
        case .transfer, .debt:
            // For transfers and debt, show all categories or none
            break
        }
        
        // Additional filtering if specific categories are provided
        if !categories.isEmpty {
            filtered = filtered.filter { categories.contains($0.name) }
        }
        
        return filtered
    }
    
    private var selectedAccount: Account? {
        if let account = accounts.first(where: { $0.name == draft.accountName }) {
            return account
        }
        return accounts.first
    }
    
    private var selectedToAccount: Account? {
        guard let toAccountName = draft.toAccountName else { return nil }
        return accounts.first(where: { $0.name == toAccountName })
    }
    
    private var selectedCategory: Category? {
        settings.categories.first { $0.name == draft.category }
    }
    
    // MARK: - Theme Color
    private var themeColor: Color {
        switch draft.type {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        case .debt:
            return .orange
        }
    }
    
    // MARK: - Sign Symbol
    private var signSymbol: String {
        switch draft.type {
        case .expense:
            return "-"
        case .income:
            return "+"
        case .transfer:
            return "↔"
        case .debt:
            return ""
        }
    }
    
    // MARK: - Transfer Icon
    private var transferIcon: String {
        return "arrow.left.arrow.right"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Segmented Control at Top
                        typeSegmentedControl
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Hero Amount Input (Center)
                        heroAmountField
                            .padding(.horizontal)
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            // Note/Title Field
                            TransactionFormRow(
                                icon: "text.alignleft",
                                title: "Note",
                                value: $draft.title,
                                placeholder: "Transaction note"
                            )
                            
                            // Category Field (Hidden for transfers and debt)
                            if draft.type != .transfer && draft.type != .debt {
                                TransactionCategoryRow(
                                    icon: "tag",
                                title: String(localized: "Category", comment: "Category field label"),
                                category: selectedCategory,
                                placeholder: String(localized: "Select Category", comment: "Category placeholder"),
                                    onTap: { showCategoryPicker = true }
                                )
                            }
                            
                            // Contact Field (Only for debt)
                            if draft.type == .debt {
                                TransactionContactRow(
                                    icon: "person.fill",
                                    title: String(localized: "Contact", comment: "Contact field label"),
                                    contact: selectedContact,
                                    placeholder: String(localized: "Select Contact", comment: "Select contact placeholder"),
                                    onTap: { showContactPicker = true }
                                )
                                
                                // Debt Type Picker (Lent vs Borrowed)
                                Picker(String(localized: "Type", comment: "Type picker"), selection: $debtTransactionType) {
                                    ForEach([DebtTransactionType.lent, DebtTransactionType.borrowed]) { type in
                                        Text(type.title).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Date Field
                            TransactionDateRow(
                                icon: "calendar",
                                title: String(localized: "Date", comment: "Date field label"),
                                date: $draft.date
                            )
                            
                            // Account Field(s)
                            if draft.type == .transfer {
                                // Transfer: From and To accounts
                                TransactionAccountRow(
                                    icon: "arrow.up.circle.fill",
                                    title: String(localized: "From Account", comment: "From account field label"),
                                    account: selectedAccount,
                                    placeholder: String(localized: "Select From Account", comment: "From account placeholder"),
                                    onTap: { showAccountPicker = true }
                                )
                                
                                // Transfer Arrow
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.down")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                    Spacer()
                                }
                                
                                TransactionAccountRow(
                                    icon: "arrow.down.circle.fill",
                                    title: String(localized: "To Account", comment: "To account field label"),
                                    account: selectedToAccount,
                                    placeholder: String(localized: "Select To Account", comment: "To account placeholder"),
                                    onTap: { showToAccountPicker = true }
                                )
                            } else {
                                // Regular transaction: Single account
                                TransactionAccountRow(
                                    icon: "creditcard",
                                    title: String(localized: "Account", comment: "Account field label"),
                                    account: selectedAccount,
                                    placeholder: String(localized: "Select Account", comment: "Account placeholder"),
                                    onTap: { showAccountPicker = true }
                                )
                            }
                            
                            // Currency Field
                            TransactionCurrencyRow(
                                icon: "dollarsign.circle",
                                title: String(localized: "Currency", comment: "Currency field label"),
                                currency: $draft.currency
                            )
                        }
                        .padding(.horizontal)
                        
                        // Recurring / Plan Section (only for expenses with future dates)
                        if draft.type == .expense && draft.date > Date() {
                            VStack(spacing: 16) {
                                // Section Header
                                HStack {
                                    Text("Recurring / Plan", comment: "Recurring plan section header")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                // Repeat Option
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Repeat", comment: "Repeat field label")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Picker(String(localized: "Repeat", comment: "Repeat picker"), selection: $repeatOption) {
                                            ForEach(RepeatOption.allCases, id: \.self) { option in
                                                Text(option.localizedTitle).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .padding(16)
                                    .background(Color.customCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal)
                                
                                // Save to Planned Payments Toggle
                                if repeatOption != .never || draft.date > Date() {
                                    Button {
                                        saveToPlannedPayments.toggle()
                                    } label: {
                                        HStack {
                                            Image(systemName: saveToPlannedPayments ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(saveToPlannedPayments ? .blue : .secondary)
                                            Text("Save to Planned Payments", comment: "Save to planned payments toggle")
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .padding(16)
                                        .background(saveToPlannedPayments ? Color.blue.opacity(0.1) : Color.customCardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(saveToPlannedPayments ? Color.blue.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Save Button
                        Button {
                            // Handle debt transactions separately
                            if draft.type == .debt {
                                handleDebtSave()
                            } else {
                                // Save regular transaction
                                onSave(draft)
                                
                                // If save to planned payments is enabled, also save to SubscriptionManager
                                if saveToPlannedPayments && draft.type == .expense {
                                    let subscription = PlannedPayment(
                                        title: draft.title.isEmpty ? "Subscription" : draft.title,
                                        amount: draft.amount,
                                        date: draft.date,
                                        status: .upcoming,
                                        accountName: draft.accountName,
                                        category: draft.category.isEmpty ? nil : draft.category,
                                        type: .subscription,
                                        isIncome: false
                                    )
                                    SubscriptionManager.shared.addSubscription(subscription)
                                }
                            }
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(draft.isValid ? draft.type.color : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!draft.isValid)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                // Delete button (only when editing)
                if isEditMode && onDelete != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .alert("Delete Transaction", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if case .edit(let id) = mode {
                        onDelete?(id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
            }
            .sheet(isPresented: $showAccountPicker) {
                accountPickerSheet(isFromAccount: true)
            }
            .sheet(isPresented: $showToAccountPicker) {
                accountPickerSheet(isFromAccount: false)
            }
            .sheet(isPresented: $showContactPicker) {
                contactPickerSheet
            }
            .onAppear {
                // Initialize amount text from draft
                if draft.amount == 0 {
                    amountText = ""
                } else {
                    amountText = formatAmount(draft.amount)
                }
                // Initialize currency from settings for new transactions
                if case .add = mode {
                    draft.currency = settings.currency
                }
                // Auto-focus amount field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAmountFocused = true
                }
            }
            .onChange(of: draft.amount) { oldValue, newValue in
                // Sync amountText when draft.amount changes externally (e.g., from segmented control)
                if newValue == 0 {
                    amountText = ""
                } else if amountText.isEmpty || abs(newValue - (Double(amountText) ?? 0)) > 0.01 {
                    // Only update if there's a significant difference to avoid conflicts
                    amountText = formatAmount(newValue)
                }
            }
            .onChange(of: draft.type) { oldValue, newValue in
                // Reset transfer-specific fields when changing type
                if newValue != .transfer {
                    draft.toAccountName = nil
                } else if oldValue != .transfer {
                    // When switching to transfer, ensure we have a valid setup
                    if draft.toAccountName == nil && accounts.count > 1 {
                        if let fromAccount = selectedAccount,
                           let toAccount = accounts.first(where: { $0.id != fromAccount.id }) {
                            draft.toAccountName = toAccount.name
                        }
                    }
                }
                
                // Clear category if it doesn't match the new transaction type
                if newValue != .transfer && newValue != .debt {
                    if let currentCategory = selectedCategory {
                        let expectedType: CategoryType = (newValue == .income) ? .income : .expense
                        if currentCategory.type != expectedType {
                            draft.category = ""
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Type Segmented Control
    private var typeSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach([TransactionType.expense, TransactionType.income, TransactionType.transfer, TransactionType.debt]) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        draft.type = type
                    }
                } label: {
                    Text(type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(draft.type == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(draft.type == type ? type.color : Color.clear)
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
                
                // Small, subtle icon for transaction type (always shown, colored only)
                if draft.type == .transfer {
                    Image(systemName: transferIcon)
                        .font(.title2)
                        .foregroundStyle(themeColor)
                } else if draft.type == .debt {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(themeColor)
                } else if !signSymbol.isEmpty {
                    Text(signSymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(themeColor)
                }
                
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
        // Remove any non-numeric characters except decimal point
        let cleaned = newValue.filter { $0.isNumber || $0 == "." }
        
        // Handle leading zero replacement: if current amount is 0 and user types a digit, replace 0
        if draft.amount == 0 && !cleaned.isEmpty {
            // If the cleaned value starts with a non-zero digit, replace the zero
            if let firstChar = cleaned.first, firstChar.isNumber, firstChar != "0" {
                // Keep the cleaned value as-is (it already replaces the zero)
                amountText = cleaned
                if let value = Double(cleaned) {
                    draft.amount = value
                }
                return
            }
        }
        
        // Update the text
        amountText = cleaned
        
        // Convert to double and update draft
        if cleaned.isEmpty {
            draft.amount = 0
        } else if let value = Double(cleaned) {
            draft.amount = value
        } else {
            // If conversion fails, keep the text but don't update amount
            // This handles cases like "5." (incomplete decimal)
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
    
    // MARK: - Category Picker Sheet
    private var categoryPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Category Grid - Clean 4-column layout
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(availableCategories) { category in
                            categoryPickerItem(category: category)
                                .id(category.id)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.customBackground)
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showCategoryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func categoryPickerItem(category: Category) -> some View {
        Button {
            draft.category = category.name
            showCategoryPicker = false
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(draft.category == category.name ? draft.type.color.opacity(0.2) : draft.type.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.iconName)
                        .font(.title3)
                        .foregroundStyle(draft.category == category.name ? draft.type.color : .secondary)
                }
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(draft.category == category.name ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func accountPickerSheet(isFromAccount: Bool) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(accounts) { account in
                        accountPickerItem(account: account, isFromAccount: isFromAccount)
                            .id(account.id)
                    }
                }
                .padding(20)
            }
            .background(Color.customBackground)
            .navigationTitle(isFromAccount ? "Select From Account" : "Select To Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if isFromAccount {
                            showAccountPicker = false
                        } else {
                            showToAccountPicker = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func handleDebtSave() {
        guard let contact = selectedContact else { return }
        
        let transaction = DebtTransaction(
            id: UUID(),
            contactId: contact.id,
            amount: draft.amount,
            type: debtTransactionType,
            date: draft.date,
            note: draft.title.isEmpty ? nil : draft.title,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        debtManager.addTransaction(transaction)
        dismiss()
    }
    
    private var contactPickerSheet: some View {
        NavigationStack {
            ScrollView {
                contactPickerList
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
    
    private var contactPickerList: some View {
        VStack(spacing: 8) {
            ForEach(debtManager.contacts) { contact in
                contactPickerItem(contact: contact)
            }
        }
        .padding()
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
    
    private func accountPickerItem(account: Account, isFromAccount: Bool) -> some View {
        Button {
            if isFromAccount {
                draft.accountName = account.name
                showAccountPicker = false
            } else {
                draft.toAccountName = account.name
                showToAccountPicker = false
            }
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
                    Text(currencyString(account.balance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let isSelected = isFromAccount ? (draft.accountName == account.name) : (draft.toAccountName == account.name)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(height: 72)
            .background({
                let isSelected = isFromAccount ? (draft.accountName == account.name) : (draft.toAccountName == account.name)
                return isSelected ? Color.accentColor.opacity(0.1) : Color.customCardBackground
            }())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke({
                        let isSelected = isFromAccount ? (draft.accountName == account.name) : (draft.toAccountName == account.name)
                        return isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08)
                    }(), lineWidth: {
                        let isSelected = isFromAccount ? (draft.accountName == account.name) : (draft.toAccountName == account.name)
                        return isSelected ? 1.5 : 1
                    }())
            )
        }
        .buttonStyle(.plain)
    }
    
    
}

struct AccountFormView: View {
    let account: Account?
    let onSave: (Account) -> Void
    let onCancel: () -> Void
    let onDelete: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var accountType: AccountType
    @State private var currency: String
    @State private var balance: Double
    @State private var includedInTotal: Bool
    @State private var isPinned: Bool
    @State private var isSavings: Bool
    @State private var selectedIcon: String
    @State private var showIconPicker = false
    @State private var showDeleteAlert = false
    
    init(account: Account?, onSave: @escaping (Account) -> Void, onCancel: @escaping () -> Void, onDelete: ((UUID) -> Void)? = nil) {
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        _name = State(initialValue: account?.name ?? "")
        _accountType = State(initialValue: account?.accountType ?? .card)
        _currency = State(initialValue: account?.currency ?? "USD")
        _balance = State(initialValue: account?.balance ?? 0)
        _includedInTotal = State(initialValue: account?.includedInTotal ?? true)
        _isPinned = State(initialValue: account?.isPinned ?? false)
        _isSavings = State(initialValue: account?.isSavings ?? false)
        _selectedIcon = State(initialValue: account?.iconName ?? CategoryIconLibrary.iconName(for: account?.accountType ?? .card))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.title)
                            }
                            .tag(type)
                        }
                    }
                    .onChange(of: accountType) { oldValue, newType in
                        // Update icon to default for new type if not custom
                        if selectedIcon == CategoryIconLibrary.iconName(for: oldValue) {
                            selectedIcon = CategoryIconLibrary.iconName(for: newType)
                        }
                    }
                    
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: selectedIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(["USD", "EUR", "PLN", "GBP"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    TextField("Current Balance", value: $balance, format: .number)
                        .keyboardType(.decimalPad)
                }
                
                Section("Settings") {
                    Toggle("Include in total balance", isOn: $includedInTotal)
                    Toggle("Pin account", isOn: $isPinned)
                    Toggle("Savings account", isOn: $isSavings)
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(account == nil ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                // Delete button (only when editing)
                if account != nil, onDelete != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedAccount = Account(
                            id: account?.id ?? UUID(),
                            name: name,
                            balance: balance,
                            includedInTotal: includedInTotal,
                            accountType: accountType,
                            currency: currency,
                            isPinned: isPinned,
                            isSavings: isSavings,
                            iconName: selectedIcon
                        )
                        onSave(updatedAccount)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let accountId = account?.id {
                        onDelete?(accountId)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this account? All associated transactions will also be deleted. This action cannot be undone.")
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    icons: CategoryIconLibrary.accountIcons,
                    selectedIcon: $selectedIcon,
                    title: "Select Account Icon"
                )
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Transaction Form Components

struct TransactionCategoryChip: View {
    let category: Category
    let isSelected: Bool
    let typeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color.opacity(0.2) : category.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.iconName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? category.color : category.color.opacity(0.7))
                }
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? category.color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TransactionFormRow: View {
    let icon: String
    let title: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            TextField(placeholder, text: $value)
                .font(.body)
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct TransactionDateRow: View {
    let icon: String
    let title: String
    @Binding var date: Date
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct TransactionContactRow: View {
    let icon: String
    let title: String
    let contact: Contact?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let contact = contact {
                    Circle()
                        .fill(contact.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(contact.initials)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        )
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(contact.name)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
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

struct TransactionCategoryRow: View {
    let icon: String
    let title: String
    let category: Category?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let category = category {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: category.iconName)
                            .font(.subheadline)
                            .foregroundStyle(category.color)
                    }
                    .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(category.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
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

struct TransactionAccountRow: View {
    let icon: String
    let title: String
    let account: Account?
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                if let account = account {
                    ZStack {
                        Circle()
                            .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
                    }
                    .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(account.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(placeholder)
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

struct TransactionCurrencyRow: View {
    let icon: String
    let title: String
    @Binding var currency: String
    
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "INR", "PLN", "RUB", "BRL", "MXN", "KRW", "SGD", "HKD", "NZD", "SEK", "NOK", "DKK"]
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Picker("", selection: $currency) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(16)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AccountDetailsView: View {
    let account: Account
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @State private var showAccountForm = false
    @State private var showBalanceEditor = false
    @State private var editedBalance: Double
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty(currency: "USD")
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    
    private var currentAccount: Account? {
        accounts.first { $0.id == account.id }
    }
    
    init(account: Account, accounts: Binding<[Account]>, transactions: Binding<[Transaction]>) {
        self.account = account
        self._accounts = accounts
        self._transactions = transactions
        _editedBalance = State(initialValue: account.balance)
    }
    
    private var accountTransactions: [Transaction] {
        transactions.filter { $0.accountName == account.name }
    }
    
    private func deleteAccount(_ accountId: UUID) {
        // Delete all transactions associated with this account
        transactions.removeAll { transaction in
            transaction.accountName == account.name || transaction.toAccountName == account.name
        }
        // Delete the account
        accounts.removeAll { $0.id == accountId }
        // Dismiss the view
        dismiss()
    }
    
    private func deleteTransactionFromAccount(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        // Update account balances
        updateAccountBalancesForDeletedTransaction(transaction)
    }
    
    private func updateAccountBalancesForDeletedTransaction(_ transaction: Transaction) {
        // Helper function to calculate balance change for a transaction
        func balanceChange(for transaction: Transaction) -> Double {
            switch transaction.type {
            case .income:
                return transaction.amount
            case .expense:
                return -transaction.amount
            case .transfer, .debt:
                return 0 // Transfers and debts don't change total balance of an account directly
            }
        }
        
        // Revert transaction's effect on account balance
        if let accountIndex = accounts.firstIndex(where: { $0.name == transaction.accountName }) {
            accounts[accountIndex].balance -= balanceChange(for: transaction)
        }
        
        // For transfers, also revert the 'to' account
        if transaction.type == .transfer, let toAccountName = transaction.toAccountName,
           let toAccountIndex = accounts.firstIndex(where: { $0.name == toAccountName }) {
            accounts[toAccountIndex].balance += transaction.amount // Add back to 'to' account
        }
    }
    
    private var totalIncome: Double {
        accountTransactions
            .filter { $0.type == .income }
            .map(\.amount)
            .reduce(0, +)
    }
    
    private var totalExpense: Double {
        accountTransactions
            .filter { $0.type == .expense }
            .map(\.amount)
            .reduce(0, +)
    }
    
    private var categories: [String] {
        Array(Set(transactions.map(\.category))).sorted()
    }
    
    private func startEditing(_ transaction: Transaction) {
        // Reset sheet state first to ensure clean state
        if showTransactionForm {
            showTransactionForm = false
            // Wait for sheet to close before opening with new mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.currentFormMode = .edit(transaction.id)
                self.draftTransaction = TransactionDraft(transaction: transaction)
                self.showTransactionForm = true
            }
        } else {
            // Set the new mode and draft
            currentFormMode = .edit(transaction.id)
            draftTransaction = TransactionDraft(transaction: transaction)
            showTransactionForm = true
        }
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        let oldTransaction: Transaction?
        
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactions.insert(newTransaction, at: 0)
            oldTransaction = nil
        case .edit(let id):
            oldTransaction = transactions.first(where: { $0.id == id })
            let updated = draft.toTransaction(existingId: id)
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions[index] = updated
            }
        }
        
        // Update account balances
        updateAccountBalancesForSave(oldTransaction: oldTransaction, newDraft: draft)
        
        showTransactionForm = false
    }
    
    private func updateAccountBalancesForSave(oldTransaction: Transaction?, newDraft: TransactionDraft) {
        // Helper function to calculate balance change for a transaction
        func balanceChange(for transaction: Transaction) -> Double {
            switch transaction.type {
            case .income:
                return transaction.amount
            case .expense:
                return -transaction.amount
            case .transfer, .debt:
                return 0
            }
        }
        
        // Revert old transaction's effect
        if let old = oldTransaction {
            if let accountIndex = accounts.firstIndex(where: { $0.name == old.accountName }) {
                accounts[accountIndex].balance -= balanceChange(for: old)
            }
            
            // Handle transfers - revert from both accounts
            if old.type == .transfer, let toAccountName = old.toAccountName,
               let toAccountIndex = accounts.firstIndex(where: { $0.name == toAccountName }) {
                accounts[toAccountIndex].balance += old.amount
            }
        }
        
        // Apply new transaction's effect
        let balanceChange = newDraft.type == .income ? newDraft.amount : (newDraft.type == .expense ? -newDraft.amount : 0)
        
        if newDraft.type == .transfer, let toAccountName = newDraft.toAccountName {
            // Transfer: subtract from fromAccount, add to toAccount
            if let fromAccountIndex = accounts.firstIndex(where: { $0.name == newDraft.accountName }) {
                accounts[fromAccountIndex].balance -= newDraft.amount
            }
            if let toAccountIndex = accounts.firstIndex(where: { $0.name == toAccountName }) {
                accounts[toAccountIndex].balance += newDraft.amount
            }
        } else if newDraft.type != .debt {
            // Income or Expense: update the account balance
            if let accountIndex = accounts.firstIndex(where: { $0.name == newDraft.accountName }) {
                accounts[accountIndex].balance += balanceChange
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with balance
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(currentAccount?.name ?? account.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            showAccountForm = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                    }
                    Text(currentAccount?.accountType.title ?? account.accountType.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Balance card with quick edit
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(currencyString(currentAccount?.balance ?? account.balance, code: settings.currency))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            editedBalance = currentAccount?.balance ?? account.balance
                            showBalanceEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Color.customSecondaryBackground)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(Color.customCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
                
                // Stats
                HStack(spacing: 12) {
                    statCard(title: "Income", value: currencyString(totalIncome, code: settings.currency), color: .green)
                    statCard(title: "Expense", value: currencyString(totalExpense, code: settings.currency), color: .red)
                }
                
                // Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transactions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    if accountTransactions.isEmpty {
                        VStack(spacing: 8) {
                            Text("No transactions yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(accountTransactions) { transaction in
                            Button {
                                startEditing(transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransactionFromAccount(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .id(transaction.id)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.customBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAccountForm) {
            AccountFormView(
                account: currentAccount ?? account,
                onSave: { updatedAccount in
                    if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                        accounts[index] = updatedAccount
                    }
                    showAccountForm = false
                },
                onCancel: {
                    showAccountForm = false
                },
                onDelete: { accountId in
                    deleteAccount(accountId)
                    showAccountForm = false
                }
            )
        }
        .sheet(isPresented: $showBalanceEditor) {
            NavigationStack {
                Form {
                    Section("Balance") {
                        TextField("Balance", value: $editedBalance, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                .background(Color.customBackground)
                .scrollContentBackground(.hidden)
                .navigationTitle("Edit Balance")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editedBalance = currentAccount?.balance ?? account.balance
                            showBalanceEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                                accounts[index].balance = editedBalance
                            }
                            showBalanceEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showTransactionForm) {
            TransactionFormView(
                draft: $draftTransaction,
                mode: currentFormMode,
                categories: categories,
                accounts: accounts,
                onSave: { draft in
                    handleSave(draft)
                },
                onCancel: {
                    showTransactionForm = false
                },
                onDelete: { id in
                    if let transaction = transactions.first(where: { $0.id == id }) {
                        deleteTransactionFromAccount(transaction)
                    }
                    showTransactionForm = false
                }
            )
            .id(currentFormMode) // Force recreation when mode changes
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
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
}

// MARK: - Contact Management Views

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
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
                Text("Create New Contact")
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
                    Text("Contact Name")
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
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
    @State private var showEditContact = false
    @State private var showAddTransaction = false
    @State private var editingTransaction: DebtTransaction?
    @State private var showDeleteAlert = false
    
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
                            Text("Net Balance")
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
                                Text("No transactions yet")
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
                                        debtManager.deleteTransaction(transaction)
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
                            Text("Delete Contact")
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
                        if editingTransaction != nil {
                            debtManager.updateTransaction(transaction)
                        } else {
                            debtManager.addTransaction(transaction)
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
            }
            .alert("Delete Contact", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    debtManager.deleteContact(currentContact ?? contact)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this contact? All associated transaction history will be permanently deleted.")
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
                    Image(systemName: transaction.type == .lent ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(transaction.type.direction.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.type.title)
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
                        Text("Settled")
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
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}


struct StartDaySelectionView: View {
    @Binding var selectedDay: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], id: \.self) { (day: Int) in
                Button {
                    selectedDay = day
                    dismiss()
                } label: {
                    HStack {
                        Text("\(day)\(daySuffix(day))")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedDay == day {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Start Day of Month")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func daySuffix(_ day: Int) -> String {
    switch day {
    case 1, 21:
        return "st"
    case 2, 22:
        return "nd"
    case 3, 23:
        return "rd"
    default:
        return "th"
    }
}

#Preview {
    ContentView()
}
