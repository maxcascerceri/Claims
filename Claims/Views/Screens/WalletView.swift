//
//  WalletView.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct WalletView: View {
    @EnvironmentObject var viewModel: SettlementsViewModel
    @State private var selectedSettlement: Settlement?
    var onSwitchToHome: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Wallet")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Asset.titleGray)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 0)
                    
                    // Balance Card
                    balanceCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Claims Section or Empty State (filed claims only, each has a filed date)
                    if viewModel.filedSettlements.isEmpty {
                        emptyState
                            .padding(.top, 48)
                    } else {
                        claimsSection
                            .padding(.top, 32)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGray6))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedSettlement) { settlement in
                SettlementDetailView(settlement: settlement)
                    .environmentObject(viewModel)
            }
        }
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Potential Earnings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text("$\(viewModel.totalFiledValue.formatted())")
                .font(.system(size: 56, weight: .black))
                .foregroundColor(.white)
            
            if viewModel.filedSettlements.count > 0 {
                Text("from \(viewModel.filedSettlements.count) claim\(viewModel.filedSettlements.count == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.75, blue: 0.4),
                    Color(red: 0.05, green: 0.55, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(red: 0.1, green: 0.7, blue: 0.3).opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("📬")
                .font(.system(size: 56))
            
            VStack(spacing: 8) {
                Text("No claims yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("When you submit a claim, it will appear here so you can track your payouts.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Asset.bodyGray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button {
                onSwitchToHome?()
            } label: {
                Text("Browse Settlements")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Asset.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Claims Section
    
    private var claimsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Claims")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Text("\(viewModel.filedSettlements.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Asset.bodyGray)
            }
            .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filedSettlements) { settlement in
                    ClaimRow(
                        settlement: settlement,
                        submittedDate: viewModel.submittedDate(for: settlement),
                        logoURL: viewModel.effectiveLogoURL(for: settlement),
                        onRemove: {
                            Haptics.medium()
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.removeFromWallet(settlement)
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        Haptics.light()
                        selectedSettlement = settlement
                    }
                }
            }
        }
    }
}

// MARK: - Claim Row

struct ClaimRow: View {
    let settlement: Settlement
    var submittedDate: Date?
    var logoURL: String? = nil
    let onRemove: () -> Void
    
    private var accentGreen: Color {
        Color(red: 0.1, green: 0.7, blue: 0.3)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Logo (remote ClassAction image when available)
            LogoView(
                iconName: settlement.logoName,
                color: settlement.logoColor,
                size: 48,
                url: logoURL
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(settlement.companyName)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                
                if let submittedDate {
                    Text("Filed \(submittedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Asset.bodyGray)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(settlement.payoutDisplay)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(accentGreen)
                
                Text("potential")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Asset.bodyGray)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    WalletView()
        .environmentObject(SettlementsViewModel())
}
