//
//  CategoryIconLibrary.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct CategoryIconLibrary {
    // Large library for transaction categories - verified SF Symbols only, no duplicates
    static let transactionIcons: [String] = [
        // Money & Finance
        "wallet.pass.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill", "chart.bar.fill", "building.columns.fill",
        "bitcoinsign.circle.fill",
        
        // Shopping
        "cart.fill", "bag.fill", "tag.fill", "gift.fill", "storefront.fill",
        "barcode", "qrcode", "tshirt.fill", "watch.fill",
        
        // Food & Drink
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "basket.fill",
        "mug.fill", "birthday.cake.fill", "hamburger.fill", "pizza.fill",
        "fish.fill", "carrot.fill",
        
        // Transport
        "car.fill", "bus.fill", "airplane", "fuelpump.fill", "tram.fill",
        "bicycle", "scooter", "motorcycle", "map.fill",
        
        // Home & Utilities
        "house.fill", "bed.double.fill", "wifi", "lightbulb.fill", "drop.fill",
        "sofa.fill", "shower.fill", "washer.fill", "bathtub.fill",
        "flame.fill", "bolt.fill", "key.fill", "lock.fill",
        
        // Health & Self-care
        "heart.fill", "pills.fill", "cross.case.fill", "scissors",
        "stethoscope", "dumbbell.fill",
        
        // Tech & Work
        "iphone", "laptopcomputer", "briefcase.fill", "printer.fill",
        "camera.fill", "headphones", "ipad",
        
        // Education & Family
        "book.fill", "graduationcap.fill", "stroller.fill",
        "pencil", "backpack.fill",
        
        // Entertainment
        "tv.fill", "music.note", "gamecontroller.fill", "film.fill",
        "ticket.fill",
        
        // Sports & Fitness
        "soccerball", "basketball.fill", "skateboard",
        
        // Pets
        "pawprint.fill", "cat.fill", "dog.fill", "bird.fill",
        
        // Tools
        "wrench.and.screwdriver.fill", "hammer.fill", "paintbrush.fill",
        
        // Nature
        "leaf.fill", "tree.fill", "sun.max.fill", "moon.fill",
        "umbrella.fill", "tent.fill",
        
        // Personal Care
        "eyeglasses", "comb.fill",
        
        // Services
        "phone.fill", "envelope.fill", "doc.text.fill", "calendar",
        "clock.fill", "bell.fill", "person.fill", "person.2.fill",
        "hand.raised.fill",
        
        // Income
        "arrow.down.circle.fill",
        
        // Subscriptions
        "star.fill", "cloud.fill",
        
        // Misc
        "crown.fill", "bookmark.fill"
    ]
    
    // Small library for account types - compact set of account icons
    static let accountIcons: [String] = [
        "wallet.pass.fill",           // Wallet
        "wallet.pass",                // Wallet (outline)
        "creditcard.fill",            // Card
        "creditcard",                 // Card (outline)
        "building.columns.fill",      // Bank
        "building.columns",           // Bank (outline)
        "banknote.fill",              // Cash
        "banknote",                   // Cash (outline)
        "lock.fill",                  // Safe
        "lock",                       // Safe (outline)
        "lock.shield.fill",           // Secure safe
        "dollarsign.circle.fill",     // Savings
        "dollarsign.circle",          // Savings (outline)
        "chart.line.uptrend.xyaxis",  // Deposit/Investment
        "chart.pie.fill",             // Investment account
        "chart.pie",                  // Investment account (outline)
        "chart.bar.fill",             // Investment tracking
        "bitcoinsign.circle.fill",    // Crypto wallet
        "bitcoinsign.circle"          // Crypto wallet (outline)
    ]
    
    static func iconName(for accountType: AccountType) -> String {
        switch accountType {
        case .cash:
            return "banknote.fill"
        case .card:
            return "creditcard.fill"
        case .bankAccount:
            return "building.columns.fill"
        }
    }
}

