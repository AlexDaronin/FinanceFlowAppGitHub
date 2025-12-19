//
//  SwiftDataModels.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Transaction Model

@Model
final class SDTransaction {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var amount: Double
    var date: Date
    var type: String // TransactionType rawValue
    var accountId: UUID // Changed from accountName to accountId
    var toAccountId: UUID? // Changed from toAccountName to toAccountId
    var currency: String
    var sourcePlannedPaymentId: UUID?
    var occurrenceDate: Date?
    
    // Legacy fields for migration (will be removed after migration)
    var accountName: String? // For backward compatibility during migration
    var toAccountName: String? // For backward compatibility during migration
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        amount: Double,
        date: Date,
        type: String,
        accountId: UUID,
        toAccountId: UUID? = nil,
        currency: String = "USD",
        sourcePlannedPaymentId: UUID? = nil,
        occurrenceDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
        self.type = type
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.currency = currency
        self.sourcePlannedPaymentId = sourcePlannedPaymentId
        self.occurrenceDate = occurrenceDate ?? date
    }
    
    func toTransaction() -> Transaction {
        Transaction(
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
    
    static func from(_ transaction: Transaction) -> SDTransaction {
        SDTransaction(
            id: transaction.id,
            title: transaction.title,
            category: transaction.category,
            amount: transaction.amount,
            date: transaction.date,
            type: transaction.type.rawValue,
            accountId: transaction.accountId,
            toAccountId: transaction.toAccountId,
            currency: transaction.currency,
            sourcePlannedPaymentId: transaction.sourcePlannedPaymentId,
            occurrenceDate: transaction.occurrenceDate
        )
    }
}

// MARK: - Account Model

@Model
final class SDAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var balance: Double
    var includedInTotal: Bool
    var accountType: String // AccountType rawValue
    var currency: String
    var isPinned: Bool
    var isSavings: Bool
    var iconName: String
    
    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        includedInTotal: Bool = true,
        accountType: String,
        currency: String = "USD",
        isPinned: Bool = false,
        isSavings: Bool = false,
        iconName: String
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.includedInTotal = includedInTotal
        self.accountType = accountType
        self.currency = currency
        self.isPinned = isPinned
        self.isSavings = isSavings
        self.iconName = iconName
    }
    
    func toAccount() -> Account {
        Account(
            id: id,
            name: name,
            balance: balance,
            includedInTotal: includedInTotal,
            accountType: AccountType(rawValue: accountType) ?? .card,
            currency: currency,
            isPinned: isPinned,
            isSavings: isSavings,
            iconName: iconName
        )
    }
    
    static func from(_ account: Account) -> SDAccount {
        SDAccount(
            id: account.id,
            name: account.name,
            balance: account.balance,
            includedInTotal: account.includedInTotal,
            accountType: account.accountType.rawValue,
            currency: account.currency,
            isPinned: account.isPinned,
            isSavings: account.isSavings,
            iconName: account.iconName
        )
    }
}

// MARK: - Credit Model

@Model
final class SDCredit {
    @Attribute(.unique) var id: UUID
    var title: String
    var totalAmount: Double
    var remaining: Double
    var paid: Double
    var monthsLeft: Int
    var dueDate: Date
    var monthlyPayment: Double
    var interestRate: Double?
    var startDate: Date?
    var paymentAccountId: UUID? // Changed from accountName to paymentAccountId
    var termMonths: Int?
    var linkedAccountId: UUID?
    
    // Legacy field for migration (will be removed after migration)
    var accountName: String? // For backward compatibility during migration
    
    init(
        id: UUID = UUID(),
        title: String,
        totalAmount: Double,
        remaining: Double,
        paid: Double,
        monthsLeft: Int,
        dueDate: Date,
        monthlyPayment: Double,
        interestRate: Double? = nil,
        startDate: Date? = nil,
        paymentAccountId: UUID? = nil,
        termMonths: Int? = nil,
        linkedAccountId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.totalAmount = totalAmount
        self.remaining = remaining
        self.paid = paid
        self.monthsLeft = monthsLeft
        self.dueDate = dueDate
        self.monthlyPayment = monthlyPayment
        self.interestRate = interestRate
        self.startDate = startDate
        self.paymentAccountId = paymentAccountId
        self.termMonths = termMonths
        self.linkedAccountId = linkedAccountId
    }
    
    func toCredit() -> Credit {
        Credit(
            id: id,
            title: title,
            totalAmount: totalAmount,
            remaining: remaining,
            paid: paid,
            monthsLeft: monthsLeft,
            dueDate: dueDate,
            monthlyPayment: monthlyPayment,
            interestRate: interestRate,
            startDate: startDate,
            paymentAccountId: paymentAccountId,
            termMonths: termMonths,
            linkedAccountId: linkedAccountId
        )
    }
    
    static func from(_ credit: Credit) -> SDCredit {
        SDCredit(
            id: credit.id,
            title: credit.title,
            totalAmount: credit.totalAmount,
            remaining: credit.remaining,
            paid: credit.paid,
            monthsLeft: credit.monthsLeft,
            dueDate: credit.dueDate,
            monthlyPayment: credit.monthlyPayment,
            interestRate: credit.interestRate,
            startDate: credit.startDate,
            paymentAccountId: credit.paymentAccountId,
            termMonths: credit.termMonths,
            linkedAccountId: credit.linkedAccountId
        )
    }
}

// MARK: - Contact Model

@Model
final class SDContact {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarColor: String
    
    init(id: UUID = UUID(), name: String, avatarColor: String = "blue") {
        self.id = id
        self.name = name
        self.avatarColor = avatarColor
    }
    
    func toContact() -> Contact {
        Contact(id: id, name: name, avatarColor: avatarColor)
    }
    
    static func from(_ contact: Contact) -> SDContact {
        SDContact(id: contact.id, name: contact.name, avatarColor: contact.avatarColor)
    }
}

// MARK: - DebtTransaction Model

@Model
final class SDDebtTransaction {
    @Attribute(.unique) var id: UUID
    var contactId: UUID
    var amount: Double
    var type: String // DebtTransactionType rawValue
    var date: Date
    var note: String?
    var isSettled: Bool
    var accountId: UUID
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        contactId: UUID,
        amount: Double,
        type: String,
        date: Date = Date(),
        note: String? = nil,
        isSettled: Bool = false,
        accountId: UUID = UUID(),
        currency: String = "USD",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.contactId = contactId
        self.amount = amount
        self.type = type
        self.date = date
        self.note = note
        self.isSettled = isSettled
        self.accountId = accountId
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDebtTransaction() -> DebtTransaction {
        DebtTransaction(
            id: id,
            contactId: contactId,
            amount: amount,
            type: DebtTransactionType(rawValue: type) ?? .lent,
            date: date,
            note: note,
            isSettled: isSettled,
            accountId: accountId == UUID() ? UUID() : accountId, // Use provided accountId or generate new one
            currency: currency.isEmpty ? "USD" : currency, // Default to USD if empty
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func from(_ transaction: DebtTransaction) -> SDDebtTransaction {
        SDDebtTransaction(
            id: transaction.id,
            contactId: transaction.contactId,
            amount: transaction.amount,
            type: transaction.type.rawValue,
            date: transaction.date,
            note: transaction.note,
            isSettled: transaction.isSettled,
            accountId: transaction.accountId,
            currency: transaction.currency,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt
        )
    }
}

// MARK: - PlannedPayment Model

@Model
final class SDPlannedPayment {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Double
    var date: Date
    var status: String // PlannedPaymentStatus rawValue
    var accountId: UUID? // Changed from accountName to accountId (optional for migration)
    var toAccountId: UUID? // Changed from toAccountName to toAccountId
    var category: String?
    var type: String // PlannedPaymentType rawValue
    var isIncome: Bool
    var totalLoanAmount: Double?
    var remainingBalance: Double?
    var startDate: Date?
    var interestRate: Double?
    var linkedCreditId: UUID?
    var isRepeating: Bool
    var repetitionFrequency: String?
    var repetitionInterval: Int?
    var selectedWeekdays: [Int]?
    var skippedDates: [Date]?
    var endDate: Date?
    
    // Legacy fields for migration (will be removed after migration)
    var accountName: String? // For backward compatibility during migration
    var toAccountName: String? // For backward compatibility during migration
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        status: String,
        accountId: UUID?,
        toAccountId: UUID? = nil,
        category: String? = nil,
        type: String,
        isIncome: Bool = false,
        totalLoanAmount: Double? = nil,
        remainingBalance: Double? = nil,
        startDate: Date? = nil,
        interestRate: Double? = nil,
        linkedCreditId: UUID? = nil,
        isRepeating: Bool = false,
        repetitionFrequency: String? = nil,
        repetitionInterval: Int? = nil,
        selectedWeekdays: [Int]? = nil,
        skippedDates: [Date]? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.status = status
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.category = category
        self.type = type
        self.isIncome = isIncome
        self.totalLoanAmount = totalLoanAmount
        self.remainingBalance = remainingBalance
        self.startDate = startDate
        self.interestRate = interestRate
        self.linkedCreditId = linkedCreditId
        self.isRepeating = isRepeating
        self.repetitionFrequency = repetitionFrequency
        self.repetitionInterval = repetitionInterval
        self.selectedWeekdays = selectedWeekdays
        self.skippedDates = skippedDates
        self.endDate = endDate
    }
    
    func toPlannedPayment() -> PlannedPayment? {
        guard let accountId = accountId else { return nil }
        let paymentStatus: PlannedPaymentStatus = (status == "upcoming") ? .upcoming : .past
        let paymentType: PlannedPaymentType = (type == "loan") ? .loan : .subscription
        
        return PlannedPayment(
            id: id,
            title: title,
            amount: amount,
            date: date,
            status: paymentStatus,
            accountId: accountId,
            toAccountId: toAccountId,
            category: category,
            type: paymentType,
            isIncome: isIncome,
            totalLoanAmount: totalLoanAmount,
            remainingBalance: remainingBalance,
            startDate: startDate,
            interestRate: interestRate,
            linkedCreditId: linkedCreditId,
            isRepeating: isRepeating,
            repetitionFrequency: repetitionFrequency,
            repetitionInterval: repetitionInterval,
            selectedWeekdays: selectedWeekdays,
            skippedDates: skippedDates,
            endDate: endDate
        )
    }
    
    static func from(_ payment: PlannedPayment) -> SDPlannedPayment {
        let statusString: String
        switch payment.status {
        case .upcoming: statusString = "upcoming"
        case .past: statusString = "past"
        }
        
        let typeString: String
        switch payment.type {
        case .subscription: typeString = "subscription"
        case .loan: typeString = "loan"
        }
        
        return SDPlannedPayment(
            id: payment.id,
            title: payment.title,
            amount: payment.amount,
            date: payment.date,
            status: statusString,
            accountId: payment.accountId,
            toAccountId: payment.toAccountId,
            category: payment.category,
            type: typeString,
            isIncome: payment.isIncome,
            totalLoanAmount: payment.totalLoanAmount,
            remainingBalance: payment.remainingBalance,
            startDate: payment.startDate,
            interestRate: payment.interestRate,
            linkedCreditId: payment.linkedCreditId,
            isRepeating: payment.isRepeating,
            repetitionFrequency: payment.repetitionFrequency,
            repetitionInterval: payment.repetitionInterval,
            selectedWeekdays: payment.selectedWeekdays,
            skippedDates: payment.skippedDates,
            endDate: payment.endDate
        )
    }
}

