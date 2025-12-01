//
//  CategoryIconLibrary.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation
import SwiftUI

struct CategoryIconLibrary {
    // Curated library - only filled/solid icons, no duplicates, essential icons only
    static let transactionIcons: [String] = [
        // ========== MONEY & FINANCE ==========
        "wallet.pass.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill", "chart.bar.fill", "building.columns.fill",
        "bitcoinsign.circle.fill", "arrow.down.circle.fill", "arrow.up.circle.fill",
        
        // ========== SHOPPING & RETAIL ==========
        "cart.fill", "bag.fill", "tag.fill", "gift.fill", "storefront.fill",
        "tshirt.fill", "watch.fill",
        
        // ========== FOOD & DINING ==========
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "basket.fill",
        "mug.fill", "birthday.cake.fill", "hamburger.fill", "pizza.fill",
        "fish.fill", "carrot.fill", "apple.fill", "takeoutbag.and.cup.and.straw.fill",
        
        // ========== TRANSPORT & TRAVEL ==========
        "car.fill", "bus.fill", "airplane", "fuelpump.fill", "tram.fill",
        "bicycle", "scooter", "motorcycle", "map.fill",
        "car.2.fill", "location.fill", "suitcase.fill",
        
        // ========== HOME & UTILITIES ==========
        "house.fill", "bed.double.fill", "wifi", "lightbulb.fill", "drop.fill",
        "sofa.fill", "shower.fill", "washer.fill", "bathtub.fill",
        "flame.fill", "bolt.fill", "key.fill", "lock.fill",
        
        // ========== HEALTH & SELF-CARE ==========
        "heart.fill", "pills.fill", "cross.case.fill", "scissors",
        "stethoscope", "dumbbell.fill", "cross.fill", "bandage.fill", "syringe.fill",
        
        // ========== TECH & WORK ==========
        "iphone", "laptopcomputer", "briefcase.fill", "printer.fill",
        "camera.fill", "headphones", "ipad", "desktopcomputer",
        "applewatch", "airpods", "speaker.fill", "display",
        
        // ========== EDUCATION & FAMILY ==========
        "book.fill", "graduationcap.fill", "stroller.fill",
        "pencil", "backpack.fill", "book.closed.fill",
        "figure.child", "person.2.fill",
        
        // ========== ENTERTAINMENT & MEDIA ==========
        "tv.fill", "music.note", "gamecontroller.fill", "film.fill",
        "ticket.fill", "mic.fill", "paintpalette.fill",
        "photo.fill", "video.fill", "play.circle.fill",
        
        // ========== SPORTS & FITNESS ==========
        "soccerball", "basketball.fill", "skateboard", "trophy.fill",
        "figure.run", "figure.walk", "dumbbell.fill",
        
        // ========== PETS & ANIMALS ==========
        "pawprint.fill", "cat.fill", "dog.fill", "bird.fill",
        
        // ========== TOOLS & MAINTENANCE ==========
        "wrench.and.screwdriver.fill", "hammer.fill", "paintbrush.fill",
        "wrench.fill", "screwdriver.fill", "toolbox.fill",
        
        // ========== NATURE & OUTDOORS ==========
        "leaf.fill", "tree.fill", "sun.max.fill", "moon.fill",
        "umbrella.fill", "tent.fill",
        
        // ========== PERSONAL CARE & BEAUTY ==========
        "eyeglasses", "comb.fill", "sparkles", "face.smiling.fill",
        "crown.fill",
        
        // ========== SERVICES & COMMUNICATION ==========
        "phone.fill", "envelope.fill", "doc.text.fill", "calendar",
        "clock.fill", "bell.fill", "person.fill", "person.2.fill",
        "message.fill", "bubble.left.fill",
        
        // ========== SUBSCRIPTIONS & RECURRING ==========
        "star.fill", "cloud.fill", "repeat",
        
        // ========== BILLS & PAYMENTS ==========
        "list.bullet.rectangle.fill", "checkmark.circle.fill",
        "exclamationmark.triangle.fill",
        
        // ========== TRAVEL & VACATION ==========
        "suitcase.fill", "globe", "location.fill",
        
        // ========== INSURANCE & LEGAL ==========
        "shield.fill", "doc.on.doc.fill",
        
        // ========== CHARITY & DONATIONS ==========
        "heart.circle.fill", "hand.thumbsup.fill",
        
        // ========== MISC & GENERAL ==========
        "bookmark.fill", "flag.fill", "pin.fill",
        "paperclip.fill", "folder.fill", "archivebox.fill"
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
        case .credit:
            return "creditcard.fill"
        }
    }
}

