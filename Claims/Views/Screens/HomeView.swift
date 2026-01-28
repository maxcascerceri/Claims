//
//  HomeView.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: SettlementsViewModel
    @State private var selectedSettlement: Settlement?
    @State private var menuSheetItem: MenuSheetItem?
    
    private let categories: [SettlementCategory] = [
        .noProof, .all, .closingSoon, .finance, .privacy, .consumer
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Get Started Card
                    GetStartedCard(
                        availableMoney: viewModel.totalPotentialValue,
                        claimsCount: viewModel.settlements.count
                    )
                    
                    // Loading or Content
                    if viewModel.isLoading && viewModel.settlements.isEmpty {
                        loadingSection
                    } else if let error = viewModel.errorMessage {
                        errorSection(error)
                    } else {
                        // Picked for You section
                        pickedForYouSection
                        
                        // Filter chips
                        FilterChipsRow(
                            selectedCategory: $viewModel.selectedCategory,
                            categories: categories
                        )
                        
                        // Settlements list
                        settlementsListSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                // Run refresh in a detached task so it isn't cancelled when the user
                // releases the pull — same behavior as "Try Again".
                do {
                    await Task.detached { @MainActor in
                        await viewModel.refresh()
                    }.value
                } catch is CancellationError {
                    // User released early; fetch continues in background and updates UI when done
                }
            }
            .background(Color(.systemGray6))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemGray6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                    } label: {
                        Image(systemName: "dollarsign")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Asset.bodyGray)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("ClaimWise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Asset.titleGray)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Haptics.light()
                            menuSheetItem = .howItWorks
                        } label: {
                            Label("How does this work", systemImage: "questionmark.circle")
                        }
                        Button {
                            Haptics.light()
                            menuSheetItem = .privacyPolicy
                        } label: {
                            Label("Privacy policy", systemImage: "hand.raised")
                        }
                        Button {
                            Haptics.light()
                            menuSheetItem = .termsOfUse
                        } label: {
                            Label("Terms of use", systemImage: "doc.text")
                        }
                        Button {
                            Haptics.light()
                            menuSheetItem = .contactSupport
                        } label: {
                            Label("Contact support", systemImage: "envelope")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Asset.bodyGray)
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .sheet(item: $selectedSettlement) { settlement in
                SettlementDetailView(settlement: settlement)
            }
            .sheet(item: $menuSheetItem) { item in
                MenuSheetView(item: item)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(viewModel.greeting()) 👋")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Asset.titleGray)
            
            Text("Claim your money.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Asset.bodyGray)
        }
    }
    
    // MARK: - Picked For You Section
    
    @ViewBuilder
    private var pickedForYouSection: some View {
        let pickedSettlements = viewModel.pickedForYou
        
        if !pickedSettlements.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Asset.accentGreen)
                    Text("Picked for You")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Asset.titleGray)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("No proof")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Asset.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Asset.accentGreen.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(pickedSettlements) { settlement in
                            CompactSettlementCard(
                                settlement: settlement,
                                isClaimed: viewModel.isClaimed(settlement),
                                logoURL: viewModel.effectiveLogoURL(for: settlement)
                            )
                            .onTapGesture {
                                Haptics.light()
                                selectedSettlement = settlement
                            }
                        }
                    }
                    .padding(.top, 2)
                    .padding(.trailing, 20)
                }
            }
        }
    }
    
    // MARK: - Settlements List Section
    
    private var settlementsListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredSettlements) { settlement in
                SettlementCard(
                    settlement: settlement,
                    isClaimed: viewModel.isClaimed(settlement),
                    logoURL: viewModel.effectiveLogoURL(for: settlement)
                ) {
                    Haptics.light()
                    selectedSettlement = settlement
                }
                .onTapGesture {
                    Haptics.light()
                    selectedSettlement = settlement
                }
            }
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading settlements...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Asset.bodyGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Asset.bodyGray)
            
            Text("Couldn't load settlements")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Asset.titleGray)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Asset.bodyGray)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Menu Sheet

enum MenuSheetItem: Identifiable {
    case howItWorks
    case privacyPolicy
    case termsOfUse
    case contactSupport
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .howItWorks: return "How does this work"
        case .privacyPolicy: return "Privacy policy"
        case .termsOfUse: return "Terms of use"
        case .contactSupport: return "Contact support"
        }
    }
}

struct MenuSheetView: View {
    let item: MenuSheetItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(placeholderContent)
                        .font(.system(size: 16))
                        .foregroundStyle(Asset.bodyGray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var placeholderContent: String {
        switch item {
        case .howItWorks:
            return "ClaimWise helps you find and file claims for class-action settlements you may be eligible for. Browse settlements, save the ones that apply to you, and get links to official claim forms."
        case .privacyPolicy:
            return "Our privacy policy explains how we collect, use, and protect your data. Full policy content can be added here or linked to a web page."
        case .termsOfUse:
            return "By using ClaimWise you agree to our terms of use. Full terms can be added here or linked to a web page."
        case .contactSupport:
            return "Need help? Reach out at support@claimwise.app or add your preferred contact method here."
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SettlementsViewModel())
}
