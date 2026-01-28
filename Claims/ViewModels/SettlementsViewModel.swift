//
//  SettlementsViewModel.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase

// Supabase client configuration
private let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ojtmqrruhmivwtlxagdt.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qdG1xcnJ1aG1pdnd0bHhhZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0Njc3ODMsImV4cCI6MjA4NTA0Mzc4M30.ObcczP16RLXloCzgQlm3CKhCZ4GefLZ7D7mlnsTYVMY"
)

private enum StorageKey {
    static let savedSettlementIDs = "savedSettlementIDs"
    static let claimedSettlementIDs = "claimedSettlementIDs"
    static let claimedSettlementSubmittedDates = "claimedSettlementSubmittedDates"
}

@MainActor
class SettlementsViewModel: ObservableObject {
    @Published var settlements: [Settlement] = []
    @Published var savedSettlementIDs: Set<UUID> = [] {
        didSet { persistSavedIDs() }
    }
    @Published var claimedSettlementIDs: Set<UUID> = [] {
        didSet { persistClaimedIDs() }
    }
    @Published var claimedSettlementSubmittedDates: [UUID: Date] = [:] {
        didSet { persistClaimedSubmittedDates() }
    }
    /// Set when user taps "File Claim" and opens external URL; cleared after "Did you file?" or on next open.
    @Published var lastSettlementOpenedForClaim: UUID?
    @Published var selectedCategory: SettlementCategory = .noProof
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Logo URLs resolved from ClassAction.org for settlements that don't have logo_url in DB.
    @Published var logoURLOverrides: [UUID: String] = [:]
    
    init() {
        loadPersistedIDs()
        Task {
            await fetchSettlements()
        }
    }
    
    private func loadPersistedIDs() {
        if let raw = UserDefaults.standard.array(forKey: StorageKey.savedSettlementIDs) as? [String] {
            savedSettlementIDs = Set(raw.compactMap { UUID(uuidString: $0) })
        }
        if let raw = UserDefaults.standard.array(forKey: StorageKey.claimedSettlementIDs) as? [String] {
            claimedSettlementIDs = Set(raw.compactMap { UUID(uuidString: $0) })
        }
        if let raw = UserDefaults.standard.dictionary(forKey: StorageKey.claimedSettlementSubmittedDates) as? [String: Double] {
            claimedSettlementSubmittedDates = Dictionary(
                uniqueKeysWithValues: raw.compactMap { key, value in
                    guard let id = UUID(uuidString: key) else { return nil }
                    return (id, Date(timeIntervalSince1970: value))
                }
            )
        }
    }
    
    private func persistSavedIDs() {
        UserDefaults.standard.set(savedSettlementIDs.map { $0.uuidString }, forKey: StorageKey.savedSettlementIDs)
    }
    
    private func persistClaimedIDs() {
        UserDefaults.standard.set(claimedSettlementIDs.map { $0.uuidString }, forKey: StorageKey.claimedSettlementIDs)
    }
    
    private func persistClaimedSubmittedDates() {
        let raw = Dictionary(uniqueKeysWithValues: claimedSettlementSubmittedDates.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        UserDefaults.standard.set(raw, forKey: StorageKey.claimedSettlementSubmittedDates)
    }
    
    // MARK: - Fetch from Supabase
    
    func fetchSettlements() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Settlement] = try await supabase
                .from("settlements")
                .select()
                .order("days_left", ascending: true)
                .execute()
                .value
            
            settlements = response
            isLoading = false
            print("✓ Loaded \(settlements.count) settlements from Supabase")
            await fetchClassActionLogosIfNeeded()
        } catch {
            isLoading = false
            // Ignore cancellation — SwiftUI's .refreshable can cancel the task when the user
            // releases the pull; don't show "cancelled" as an error. "Try Again" works because
            // it runs in a different, non-cancelled task.
            if error is CancellationError {
                return
            }
            errorMessage = error.localizedDescription
            print("✗ Error fetching settlements: \(error)")
        }
    }
    
    // MARK: - ClassAction logo images
    
    /// Fetches ClassAction.org settlements page, parses logo URLs per card (name/slug + image),
    /// and fills logoURLOverrides for our settlements that don't already have logoUrl.
    /// Matches by sourceId (slug) first, then normalized name, then slug derived from name.
    private func fetchClassActionLogosIfNeeded() async {
        let needLogos = settlements.filter { ($0.logoUrl ?? "").isEmpty }
        guard !needLogos.isEmpty else { return }
        let maps = await ClassActionLogoService.fetchLogoMaps()
        var overrides: [UUID: String] = [:]
        for s in needLogos {
            // 1. Match by sourceId (often the ClassAction slug, e.g. "data-breach-23andme")
            let slugKey = s.sourceId.lowercased()
            if let url = maps.slugToURL[slugKey] {
                overrides[s.id] = url
                continue
            }
            // 2. Match by normalized full name (e.g. "23andme - data breach")
            let nameKey = ClassActionLogoService.normalizeName(s.name)
            if let url = maps.nameToURL[nameKey] {
                overrides[s.id] = url
                continue
            }
            // 3. Match by slug derived from our name (e.g. "23andme-data-breach")
            let derivedSlug = ClassActionLogoService.slugFromName(s.name)
            if !derivedSlug.isEmpty, let url = maps.slugToURL[derivedSlug] {
                overrides[s.id] = url
            }
        }
        if !overrides.isEmpty {
            logoURLOverrides = logoURLOverrides.merging(overrides) { _, new in new }
            print("✓ Resolved \(overrides.count) ClassAction logo URLs")
        }
    }
    
    /// Returns the logo URL to use for a settlement: DB logo_url, else ClassAction override.
    func effectiveLogoURL(for settlement: Settlement) -> String? {
        if let url = settlement.logoUrl, !url.isEmpty { return url }
        return logoURLOverrides[settlement.id]
    }
    
    // MARK: - Computed Properties
    
    /// "Picked for You" - Top 5 major brands with no proof required, excluding filed and past-deadline
    var pickedForYou: [Settlement] {
        settlements
            .filter { !$0.isPastDeadline && $0.majorBrand && $0.noProofRequired && !claimedSettlementIDs.contains($0.id) }
            .sorted { ($0.daysLeft ?? 999) < ($1.daysLeft ?? 999) }
            .prefix(5)
            .map { $0 }
    }
    
    var featuredSettlement: Settlement? {
        // Return the one closing soonest that has a deadline (excludes past-deadline)
        settlements
            .filter { !$0.isPastDeadline && $0.daysLeft != nil && $0.daysLeft! > 0 }
            .min(by: { ($0.daysLeft ?? 999) < ($1.daysLeft ?? 999) })
    }
    
    var filteredSettlements: [Settlement] {
        var result = settlements.filter { !$0.isPastDeadline }
        
        // Filter by category
        switch selectedCategory {
        case .all:
            result = result.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .noProof:
            result = result.filter { $0.noProofRequired }
        case .closingSoon:
            result = result.filter { $0.daysRemaining <= 7 && $0.daysRemaining >= 0 }
        case .finance:
            result = result.filter { $0.settlementCategory == .finance }
        case .privacy:
            result = result.filter { $0.settlementCategory == .privacy }
        case .consumer:
            result = result.filter { $0.settlementCategory == .consumer }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.companyName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Exclude filed – they only show in wallet
        result = result.filter { !claimedSettlementIDs.contains($0.id) }
        
        // Major brands first within the filtered list, then by newest
        result = result.sorted { s1, s2 in
            let m1 = s1.isMajorBrand ?? false
            let m2 = s2.isMajorBrand ?? false
            if m1 != m2 { return m1 }
            return (s1.createdAt ?? "") > (s2.createdAt ?? "")
        }
        
        return result
    }
    
    var savedSettlements: [Settlement] {
        settlements.filter { savedSettlementIDs.contains($0.id) }
    }
    
    /// Settlements the user has filed a claim for (each has a submitted date). Use for wallet "Your Claims" so every row can show the filed date.
    var filedSettlements: [Settlement] {
        settlements.filter { claimedSettlementIDs.contains($0.id) }
    }
    
    var totalPotentialValue: Int {
        settlements.reduce(0) { sum, settlement in
            sum + Int(settlement.payoutMax ?? settlement.payoutMin ?? 0)
        }
    }
    
    var totalClaimedValue: Int {
        savedSettlements.reduce(0) { sum, settlement in
            sum + Int(settlement.payoutMax ?? settlement.payoutMin ?? 0)
        }
    }
    
    /// Total potential value of filed claims (for wallet balance when showing "Your Claims").
    var totalFiledValue: Int {
        filedSettlements.reduce(0) { sum, settlement in
            sum + Int(settlement.payoutMax ?? settlement.payoutMin ?? 0)
        }
    }
    
    // MARK: - Actions
    
    func toggleSaved(_ settlement: Settlement) {
        if savedSettlementIDs.contains(settlement.id) {
            savedSettlementIDs.remove(settlement.id)
        } else {
            savedSettlementIDs.insert(settlement.id)
        }
    }
    
    func isSaved(_ settlement: Settlement) -> Bool {
        savedSettlementIDs.contains(settlement.id)
    }
    
    /// User has filed a claim for this settlement. Adds to saved (wallet), stores submitted date, and persists.
    func markAsClaimed(_ settlement: Settlement) {
        let now = Date()
        claimedSettlementIDs.insert(settlement.id)
        savedSettlementIDs.insert(settlement.id)
        var dates = claimedSettlementSubmittedDates
        dates[settlement.id] = now
        claimedSettlementSubmittedDates = dates
        lastSettlementOpenedForClaim = nil
    }
    
    func isClaimed(_ settlement: Settlement) -> Bool {
        claimedSettlementIDs.contains(settlement.id)
    }
    
    /// Removes a settlement from the wallet (saved + filed) so it no longer appears in "Your Claims".
    func removeFromWallet(_ settlement: Settlement) {
        savedSettlementIDs.remove(settlement.id)
        claimedSettlementIDs.remove(settlement.id)
        var dates = claimedSettlementSubmittedDates
        dates[settlement.id] = nil
        claimedSettlementSubmittedDates = dates
    }
    
    func submittedDate(for settlement: Settlement) -> Date? {
        claimedSettlementSubmittedDates[settlement.id]
    }
    
    func clearLastOpenedForClaim() {
        lastSettlementOpenedForClaim = nil
    }
    
    func refresh() async {
        await fetchSettlements()
    }
    
    func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Hello"
        }
    }
}
