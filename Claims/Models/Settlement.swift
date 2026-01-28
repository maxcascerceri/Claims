//
//  Settlement.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import Foundation
import SwiftUI

// MARK: - Settlement Model (from Supabase)

struct Settlement: Identifiable, Hashable, Codable {
    let id: UUID
    let sourceId: String
    let name: String
    let companyName: String
    let payoutMin: Double?
    let payoutMax: Double?
    let deadline: String?          // Date as string "2026-01-27"
    let daysLeft: Int?
    let description: String?
    let requiresProof: Bool?
    let claimUrl: String?
    let sourceUrl: String?
    let isFeatured: Bool?
    let logoUrl: String?
    let createdAt: String?         // Timestamp as string
    let updatedAt: String?         // Timestamp as string
    
    // New fields from scraper
    let caseType: String?          // e.g., "Data Breach", "FTC Case"
    let payoutDisplayDB: String?   // Pre-formatted payout string from scraper
    let aboutText: String?         // Case summary – what the settlement is about (about_text)
    let eligibilityText: String?   // Who can claim
    let category: String?          // "Finance", "Privacy", "Consumer"
    let isMajorBrand: Bool?        // For "Picked for You" feature
    
    // Map database column names to Swift property names
    enum CodingKeys: String, CodingKey {
        case id
        case sourceId = "source_id"
        case name
        case companyName = "company_name"
        case payoutMin = "payout_min"
        case payoutMax = "payout_max"
        case deadline
        case daysLeft = "days_left"
        case description
        case requiresProof = "requires_proof"
        case claimUrl = "claim_url"
        case sourceUrl = "source_url"
        case isFeatured = "is_featured"
        case logoUrl = "logo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case caseType = "case_type"
        case payoutDisplayDB = "payout_display"
        case aboutText = "about_text"
        case eligibilityText = "eligibility"
        case category
        case isMajorBrand = "is_major_brand"
    }
    
    // Parse deadline string to Date if needed
    var deadlineDate: Date? {
        guard let deadline = deadline else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: deadline)
    }
    
    // MARK: - Computed Properties
    
    var payoutDisplay: String {
        // Prefer the pre-formatted display from DB
        if let display = payoutDisplayDB, !display.isEmpty {
            return display
        }
        
        // Fallback to computed value
        let min = Int(payoutMin ?? 0)
        let max = payoutMax != nil ? Int(payoutMax!) : nil
        
        if min == 0 && max == nil {
            return "Varies"
        }
        
        if let max = max {
            if min == max {
                return "$\(min.formatted())"
            }
            return "$\(min.formatted())-$\(max.formatted())"
        }
        return "$\(min.formatted())+"
    }
    
    var daysRemaining: Int {
        daysLeft ?? 999
    }
    
    /// True if we should not show this settlement: 0 days left or deadline date has passed.
    var isPastDeadline: Bool {
        if daysRemaining <= 0 { return true }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let d = deadlineDate, d < startOfToday { return true }
        return false
    }
    
    var urgencyLevel: UrgencyLevel {
        let days = daysRemaining
        if days <= 7 {
            return .critical
        } else if days <= 14 {
            return .high
        } else if days <= 30 {
            return .medium
        }
        return .normal
    }
    
    var noProofRequired: Bool {
        !(requiresProof ?? true)
    }
    
    var isUncapped: Bool {
        payoutMax == nil && (payoutMin ?? 0) > 0
    }
    
    var externalURL: String {
        // Prefer claim URL, fall back to source URL
        if let url = claimUrl, !url.isEmpty {
            return url
        }
        return sourceUrl ?? ""
    }
    
    /// About / case summary: what the settlement is about. Use about_text, else description.
    var aboutContent: String? {
        if let about = aboutText, !about.isEmpty { return about }
        if let desc = description, !desc.isEmpty { return desc }
        return nil
    }
    
    /// Who can claim. Use eligibility only (not description) so About and Eligibility can differ.
    var eligibility: [String] {
        if let eligibility = eligibilityText, !eligibility.isEmpty {
            return [eligibility]
        }
        return ["Check the official settlement website for eligibility details"]
    }
    
    /// The primary category from the database
    var settlementCategory: SettlementCategory {
        guard let cat = category?.lowercased() else { return .consumer }
        switch cat {
        case "finance": return .finance
        case "privacy": return .privacy
        case "consumer": return .consumer
        default: return .consumer
        }
    }
    
    /// Check if this is a major brand (for Picked for You)
    var majorBrand: Bool {
        isMajorBrand ?? false
    }
    
    // For UI - generate a color from company name
    var logoColor: Color {
        let hash = companyName.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    // For UI - generate an icon from category
    var logoName: String {
        if name.lowercased().contains("data breach") { return "lock.shield" }
        if name.lowercased().contains("health") || name.lowercased().contains("medical") { return "heart" }
        if name.lowercased().contains("bank") || name.lowercased().contains("credit") { return "dollarsign.circle" }
        if name.lowercased().contains("car") || name.lowercased().contains("vehicle") { return "car" }
        if name.lowercased().contains("food") || name.lowercased().contains("pet") { return "leaf" }
        return "building.2"
    }
}

// MARK: - Urgency Level

enum UrgencyLevel {
    case critical, high, medium, normal
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .normal: return .gray
        }
    }
}

// MARK: - Settlement Category

enum SettlementCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case noProof = "No Proof"
    case closingSoon = "Closing Soon"
    case finance = "Finance"
    case privacy = "Privacy"
    case consumer = "Consumer"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .noProof: return "checkmark.seal"
        case .closingSoon: return "clock"
        case .finance: return "dollarsign.circle"
        case .privacy: return "lock.shield"
        case .consumer: return "cart"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .all: return .gray
        case .noProof: return .green
        case .closingSoon: return .orange
        case .finance: return .blue
        case .privacy: return .purple
        case .consumer: return .teal
        }
    }
}
