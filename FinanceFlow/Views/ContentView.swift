//
//  ContentView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import Charts
import Combine

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var debtManager = DebtManager()
    
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
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                }
            
            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            AIChatView()
                .tabItem {
                    Label("AI Chat", systemImage: "message.circle")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(colorScheme)
        .environmentObject(settings)
        .environmentObject(debtManager)
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
    @State private var draftTransaction = TransactionDraft.empty
    
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
                    }
                )
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
        draftTransaction = TransactionDraft(type: type)
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
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var showDatePicker = false
    @State private var editingTransaction: DebtTransaction?
    
    init(contact: Contact? = nil, debtManager: DebtManager, onSave: @escaping (Contact, DebtTransaction) -> Void, onCancel: @escaping () -> Void) {
        self.contact = contact
        self.debtManager = debtManager
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedContact = State(initialValue: contact)
        if let contact = contact {
            _contactName = State(initialValue: contact.name)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Transaction type selector
                    transactionTypeSelector
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    
                    VStack(spacing: 16) {
                        // Contact selection/creation
                        contactSection
                        
                        // Amount field
                        amountField
                        
                        // Date section
                        dateSection
                        
                        // Note field
                        noteField
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.customBackground)
            .navigationTitle(editingTransaction == nil ? "Add Debt" : "Edit Debt")
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
                        handleSave()
                    }
                    .disabled(!isValid)
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
            .sheet(isPresented: $showDatePicker) {
                compactDatePicker
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if let contact = contact {
                selectedContact = contact
                contactName = contact.name
            }
            if let transaction = editingTransaction {
                amount = transaction.amount
                date = transaction.date
                note = transaction.note ?? ""
                transactionType = transaction.type
            }
        }
    }
    
    private var isValid: Bool {
        (!contactName.trimmingCharacters(in: .whitespaces).isEmpty || selectedContact != nil) && amount > 0
    }
    
    private func handleSave() {
        let finalContact: Contact
        if let existing = selectedContact, debtManager.contacts.contains(where: { $0.id == existing.id }) {
            // Use existing contact from database
            finalContact = existing
        } else if let existing = selectedContact {
            // New contact that was just created in picker
            finalContact = existing
        } else {
            // Create new contact
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
    
    private var transactionTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Transaction Type", selection: $transactionType) {
                ForEach(DebtTransactionType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var contactSection: some View {
        Button {
            showContactPicker = true
        } label: {
            HStack(spacing: 12) {
                if let contact = selectedContact {
                    ZStack {
                        Circle()
                            .fill(contact.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(contact.initials)
                            .font(.headline)
                            .foregroundStyle(contact.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(contact.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Select or create contact")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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
    
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text(transactionType == .lent ? "+" : "-")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(transactionType.direction.color.opacity(0.6))
                TextField("0.00", value: $amount, format: .number)
                    .font(.system(size: 36, weight: .light))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var dateSection: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDate(date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
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
    
    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (Optional)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Add a note", text: $note, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .padding(16)
                .background(Color.customCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
    
    private var compactDatePicker: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick date buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickDateButton(title: "Today", date: Date())
                        quickDateButton(title: "Yesterday", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                        quickDateButton(title: "Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Divider()
                
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }
            .background(Color.customBackground)
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func quickDateButton(title: String, date: Date) -> some View {
        Button {
            self.date = date
            showDatePicker = false
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(formatDate(date))
                    .font(.caption2)
            }
            .foregroundStyle(self.date.isSameDay(as: date) ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(self.date.isSameDay(as: date) ? Color.accentColor : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

struct CreditCard: View {
    @EnvironmentObject var settings: AppSettings
    let credit: Credit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Duration
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(credit.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(credit.monthsLeft) months left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(credit.remaining, code: settings.currency))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", credit.progress))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.customSecondaryBackground)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.customCardBackground)
                            .frame(width: geometry.size.width * (credit.progress / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Financial Details
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.totalAmount, code: settings.currency))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.customSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyString(credit.paid, code: settings.currency))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.customSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Due Date & Payment
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Due Date: \(formatDateForCredit(credit.dueDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(currencyString(credit.monthlyPayment, code: settings.currency)) /month")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            // Edit Button
            Button {
                // Edit action
            } label: {
                HStack {
                    Image(systemName: "pencil")
                        .font(.caption)
                    Text("Edit")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.customSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    }
}

struct SubscriptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var subscriptions = PlannedPayment.sample.filter { $0.type == .subscription && $0.status == .upcoming }
    @State private var showAddSubscriptionSheet = false
    @State private var showEditSubscriptionSheet = false
    @State private var selectedSubscription: PlannedPayment?
    
    private var totalMonthly: Double {
        subscriptions.map(\.amount).reduce(0, +)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscriptions")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Manage your recurring payments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Summary Card - Monthly Burn Rate
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly Burn Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currencyString(totalMonthly, code: settings.currency))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.customCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Subscriptions List
                        VStack(spacing: 12) {
                            if subscriptions.isEmpty {
                                emptyStateView
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                            } else {
                                ForEach(subscriptions) { subscription in
                                    SubscriptionCard(
                                        subscription: subscription,
                                        onTap: {
                                            selectedSubscription = subscription
                                            showEditSubscriptionSheet = true
                                        },
                                        onDelete: {
                                            if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                                                subscriptions.remove(at: index)
                                            }
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 120)
                }
                
                // Floating Action Button
                floatingActionButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddSubscriptionSheet) {
                AddPaymentFormView(
                    paymentType: .subscription,
                    onSave: { payment in
                        subscriptions.append(payment)
                        showAddSubscriptionSheet = false
                    },
                    onCancel: {
                        showAddSubscriptionSheet = false
                    }
                )
                .environmentObject(settings)
            }
            .sheet(isPresented: $showEditSubscriptionSheet) {
                if let subscription = selectedSubscription {
                    AddPaymentFormView(
                        paymentType: .subscription,
                        existingPayment: subscription,
                        onSave: { updatedPayment in
                            if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                                subscriptions[index] = updatedPayment
                            }
                            showEditSubscriptionSheet = false
                            selectedSubscription = nil
                        },
                        onCancel: {
                            showEditSubscriptionSheet = false
                            selectedSubscription = nil
                        }
                    )
                    .environmentObject(settings)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("No subscriptions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showAddSubscriptionSheet = true
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
    }
}

struct SubscriptionCard: View {
    @EnvironmentObject var settings: AppSettings
    let subscription: PlannedPayment
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    
    init(subscription: PlannedPayment, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.subscription = subscription
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    private var serviceIcon: String {
        // Use category-based icons or default
        if let category = subscription.category {
            switch category.lowercased() {
            case "entertainment":
                return "tv.fill"
            case "utilities":
                return "bolt.fill"
            case "housing":
                return "house.fill"
            default:
                return "arrow.triangle.2.circlepath"
            }
        }
        return "arrow.triangle.2.circlepath"
    }
    
    private var iconColor: Color {
        if let category = subscription.category {
            switch category.lowercased() {
            case "entertainment":
                return .purple
            case "utilities":
                return .yellow
            case "housing":
                return .blue
            default:
                return .accentColor
            }
        }
        return .accentColor
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // Service Icon (Left)
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: serviceIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                
                // Name and Date (Center)
                HStack(spacing: 8) {
                    Text(subscription.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(shortDate(subscription.date))
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                // Amount (Right)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyString(subscription.amount, code: settings.currency))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("/mo")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
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
                Section("General") {
                    Picker("Currency", selection: $settings.currency) {
                        ForEach(["USD", "EUR", "PLN", "GBP"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ThemeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Stepper(value: $settings.startDay, in: 1...28) {
                        Text("Start day of month: \(settings.startDay)")
                    }
                    Picker("Language", selection: $settings.language) {
                        ForEach(["English", "Polski", "Deutsch"], id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                }
                
                Section("Accounts & Categories") {
                    Toggle("Include cash in totals", isOn: $settings.includeCashInTotals)
                    NavigationLink("Manage categories") {
                        CategoryManagementView()
                            .environmentObject(settings)
                    }
                    NavigationLink("Manage accounts") {
                        Text("Accounts editor coming soon.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Payment reminders", isOn: $settings.notificationsEnabled)
                    Toggle("Subscription alerts", isOn: $settings.subscriptionAlerts)
                }
                
                Section("Data & Backup") {
                    Button("Export local backup") {
                        // TODO: integrate backup flow
                    }
                    Button("Restore from backup") {
                        // TODO: integrate restore flow
                    }
                }
                
                Section("Premium") {
                    Button(role: settings.premiumEnabled ? .destructive : .none) {
                        settings.premiumEnabled.toggle()
                    } label: {
                        Text(settings.premiumEnabled ? "Cancel subscription" : "Start premium trial")
                            .foregroundStyle(settings.premiumEnabled ? .red : .accentColor)
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
    }
}
struct TransactionsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var transactions = Transaction.sample
    @State private var plannedPayments = PlannedPayment.sample
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedType: TransactionType?
    @State private var showActionMenu = false
    @State private var showTransactionForm = false
    @State private var currentFormMode: TransactionFormMode = .add(.expense)
    @State private var draftTransaction = TransactionDraft.empty
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
                                                
                                                // Transactions for this day
                                                ForEach(dayGroup.transactions) { transaction in
                                                    Button {
                                                        startEditing(transaction)
                                                    } label: {
                                                        TransactionRow(transaction: transaction)
                                                    }
                                                    .buttonStyle(.plain)
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
                .navigationTitle("Transactions")
                .searchable(text: $searchText, prompt: "Search transactions")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if selectedCategory != nil {
                            Button("Reset") {
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
                    }
                )
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
                    Text("Today")
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
                Text("Missed")
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
                Text("Future")
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
                Text("Upcoming Payments")
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
            Button("All Categories") {
                selectedCategory = nil
            }
            Divider()
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                }
            }
        } label: {
            Label(selectedCategory ?? "Categories", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private var typeMenu: some View {
        Menu {
            Button("All Types") {
                selectedType = nil
            }
            Divider()
            ForEach(TransactionType.allCases) { type in
                Button(type.title) {
                    selectedType = type
                }
            }
        } label: {
            Label(selectedType?.title ?? "Types", systemImage: "slider.horizontal.3")
        }
    }
    
    
    private var resetFilterChip: some View {
        Button {
            withAnimation(.spring) {
                selectedCategory = nil
            }
        } label: {
            HStack {
                Text("Category: \(selectedCategory ?? "")")
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
            Text("No results")
                .font(.headline)
            Text("Try changing your search or filters.")
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
            Text("No upcoming payments")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("You don't have any planned payments scheduled.")
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
            Text("No missed payments")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("All your payments are up to date.")
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
            dateString = "Today"
        } else if isYesterday {
            dateString = "Yesterday"
        } else if isTomorrow {
            dateString = "Tomorrow"
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
        draftTransaction = TransactionDraft(type: type)
        showTransactionForm = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showActionMenu = false
        }
    }
    
    private func startEditing(_ transaction: Transaction) {
        currentFormMode = .edit(transaction.id)
        draftTransaction = TransactionDraft(transaction: transaction)
        showTransactionForm = true
    }
    
    private func handleSave(_ draft: TransactionDraft) {
        switch currentFormMode {
        case .add:
            let newTransaction = draft.toTransaction(existingId: nil)
            transactions.insert(newTransaction, at: 0)
        case .edit(let id):
            let updated = draft.toTransaction(existingId: id)
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                transactions[index] = updated
            }
        }
        showTransactionForm = false
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
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .foregroundStyle(transaction.type.color)
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
            
            Text(transaction.displayAmount(currencyCode: settings.currency))
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
        payment.status == .past || payment.date < Date() ? .orange : .blue
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
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showToAccountPicker = false
    @State private var showDatePicker = false
    
    private var availableCategories: [Category] {
        if categories.isEmpty {
            return settings.categories
        }
        return settings.categories.filter { categories.contains($0.name) }
    }
    
    private var selectedCategory: Category? {
        settings.categories.first { $0.name == draft.category }
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                formContent
            }
            .background(Color.customBackground)
            .navigationTitle(mode.title)
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
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
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
            .sheet(isPresented: $showDatePicker) {
                compactDatePicker
            }
        }
        .presentationDetents([.large])
    }
    
    private var formContent: some View {
        VStack(spacing: 0) {
            // Large Amount Field at Top
            amountField
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            
            // Type Picker
            typePicker
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
                    VStack(spacing: 16) {
                        // Category Section (hidden for transfers)
                        if draft.type != .transfer {
                            categorySection
                        }
                        
                        // Account Section(s)
                        if draft.type == .transfer {
                            // Transfer: Show From and To accounts
                            transferAccountSections
                        } else {
                            // Regular transaction: Show single account
                            accountSection
                        }
                        
                        // Date Section
                        dateSection
                        
                        // Title Field
                        titleField
                    }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Amount Field
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text(draft.type == .expense ? "-" : draft.type == .income ? "+" : "")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(draft.type.color.opacity(0.6))
                TextField("0.00", value: $draft.amount, format: .number)
                    .font(.system(size: 48, weight: .light))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.customCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Type Picker
    private var typePicker: some View {
        Picker("Type", selection: $draft.type) {
            ForEach(TransactionType.allCases) { type in
                Text(type.title).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        Button {
            showCategoryPicker = true
        } label: {
            HStack(spacing: 12) {
                if let selected = selectedCategory {
                    ZStack {
                        Circle()
                            .fill(draft.type.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: selected.iconName)
                            .font(.headline)
                            .foregroundStyle(draft.type.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selected.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "tag")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Select Category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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
    
    private var categoryPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Category Grid
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
    
    // MARK: - Account Section
    private var accountSection: some View {
        accountButton(
            account: selectedAccount,
            label: "Account",
            placeholder: "Select Account",
            onTap: { showAccountPicker = true }
        )
    }
    
    // MARK: - Transfer Account Sections
    private var transferAccountSections: some View {
        VStack(spacing: 16) {
            // From Account
            accountButton(
                account: selectedAccount,
                label: "From Account",
                placeholder: "Select From Account",
                icon: "arrow.up.circle.fill",
                onTap: { showAccountPicker = true }
            )
            
            // Transfer Arrow
            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
            
            // To Account
            accountButton(
                account: selectedToAccount,
                label: "To Account",
                placeholder: "Select To Account",
                icon: "arrow.down.circle.fill",
                onTap: { showToAccountPicker = true }
            )
        }
    }
    
    private func accountButton(account: Account?, label: String, placeholder: String, icon: String? = nil, onTap: @escaping () -> Void) -> some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                if let account = account {
                    ZStack {
                        Circle()
                            .fill(account.accountType == .cash ? Color.green.opacity(0.15) : account.accountType == .card ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon ?? account.iconName)
                            .font(.headline)
                            .foregroundStyle(account.accountType == .cash ? .green : account.accountType == .card ? .blue : .purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(account.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon ?? "creditcard")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(placeholder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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
        .presentationDetents([.medium, .large])
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
    
    // MARK: - Date Section
    private var dateSection: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDate(draft.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
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
    
    private var compactDatePicker: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick date buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickDateButton(title: "Today", date: Date())
                        quickDateButton(title: "Yesterday", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                        quickDateButton(title: "Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Divider()
                
                DatePicker("", selection: $draft.date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }
            .background(Color.customBackground)
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func quickDateButton(title: String, date: Date) -> some View {
        Button {
            draft.date = date
            showDatePicker = false
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(formatDate(date))
                    .font(.caption2)
            }
            .foregroundStyle(draft.date.isSameDay(as: date) ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(draft.date.isSameDay(as: date) ? Color.accentColor : Color.customCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Title Field
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Transaction title", text: $draft.title)
                .font(.subheadline)
                .padding(16)
                .background(Color.customCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct AccountFormView: View {
    let account: Account?
    let onSave: (Account) -> Void
    let onCancel: () -> Void
    
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
    
    init(account: Account?, onSave: @escaping (Account) -> Void, onCancel: @escaping () -> Void) {
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        
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

struct AccountDetailsView: View {
    let account: Account
    @Binding var accounts: [Account]
    let transactions: [Transaction]
    @State private var showAccountForm = false
    @State private var showBalanceEditor = false
    @State private var editedBalance: Double
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings
    
    private var currentAccount: Account? {
        accounts.first { $0.id == account.id }
    }
    
    init(account: Account, accounts: Binding<[Account]>, transactions: [Transaction]) {
        self.account = account
        self._accounts = accounts
        self.transactions = transactions
        _editedBalance = State(initialValue: account.balance)
    }
    
    private var accountTransactions: [Transaction] {
        transactions.filter { $0.accountName == account.name }
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
                        VStack(spacing: 8) {
                            ForEach(accountTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
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

// Update DebtFormView init to support editing
extension DebtFormView {
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
}

#Preview {
    ContentView()
}
