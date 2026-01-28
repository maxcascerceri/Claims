//
//  SettlementCard.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct SettlementCard: View {
    let settlement: Settlement
    var isClaimed: Bool = false
    var logoURL: String? = nil
    var onClaim: (() -> Void)? = nil
    
    private var isExpiringSoon: Bool { settlement.daysRemaining < 7 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section: Logo, Name, Tags
            HStack(alignment: .top, spacing: 10) {
                // Logo (remote image from ClassAction when available)
                LogoView(
                    iconName: settlement.logoName,
                    color: settlement.logoColor,
                    size: 44,
                    url: logoURL
                )
                
                // Name and badges
                VStack(alignment: .leading, spacing: 4) {
                    Text(settlement.companyName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // No proof / Proof required + Days left, inline
                    HStack(spacing: 6) {
                        if settlement.noProofRequired {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("No proof")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Asset.accentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Asset.accentGreen.opacity(0.15))
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Proof required")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Asset.proofRequiredYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Asset.proofRequiredYellow.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        HStack(spacing: 4) {
                            if isExpiringSoon {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(settlement.daysRemaining) Days Left")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isExpiringSoon ? .orange : Asset.bodyGray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            
            // Divider
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Bottom Section: Payout + Claim button
            HStack {
                // Payout
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payout")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Asset.bodyGray)
                    
                    Text(settlement.payoutDisplay)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Asset.accentGreen)
                }
                
                Spacer()
                
                // Claim button
                if let onClaim = onClaim, !isClaimed {
                    Button {
                        Haptics.medium()
                        onClaim()
                    } label: {
                        Text("Claim")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Asset.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isExpiringSoon ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .overlay {
            if isClaimed {
                Asset.accentGreen.opacity(0.65)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44, weight: .medium))
                            Text("Filed")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                    .allowsHitTesting(false)
            }
        }
    }
}

struct LogoView: View {
    let iconName: String
    let color: Color
    var size: CGFloat = 52
    /// When set, shows this remote image instead of the icon+color fallback.
    var url: String? = nil
    
    var body: some View {
        Group {
            if let url = url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        fallbackView
                    case .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
    
    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(color.gradient)
            Image(systemName: iconName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// Compact card for horizontal scroll — the card IS the logo (image or gradient + icon), then name + days
struct CompactSettlementCard: View {
    let settlement: Settlement
    var isClaimed: Bool = false
    var logoURL: String? = nil
    
    private var isExpiringSoon: Bool { settlement.daysRemaining < 7 }
    
    private static let badgeOverhang: CGFloat = 14
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card body: offset down so badge has room above
            cardBody
                .offset(y: Self.badgeOverhang)
            
            // Payout badge in its own layer so it's never clipped by the card's rounded corners
            Text(settlement.payoutDisplay)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Asset.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white, lineWidth: 2.5)
                )
                .padding(8)
        }
        .frame(width: 130, height: cardBodyHeight + Self.badgeOverhang)
    }
    
    private var cardBodyHeight: CGFloat { 88 + 1 + 62 }
    
    private var cardBody: some View {
        VStack(spacing: 0) {
            Group {
                if let logoURL = logoURL, let url = URL(string: logoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            ZStack {
                                Rectangle().fill(settlement.logoColor.gradient)
                                Image(systemName: settlement.logoName)
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        @unknown default:
                            ZStack {
                                Rectangle().fill(settlement.logoColor.gradient)
                                Image(systemName: settlement.logoName)
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .fill(settlement.logoColor.gradient)
                        Image(systemName: settlement.logoName)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 88)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
            
            VStack(spacing: 4) {
                Text(settlement.companyName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack(spacing: 3) {
                    if isExpiringSoon {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                    }
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                    Text("\(settlement.daysRemaining) Days Left")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isExpiringSoon ? .orange : Asset.bodyGray)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .frame(width: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isExpiringSoon ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .overlay {
            if isClaimed {
                Asset.accentGreen.opacity(0.65)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36, weight: .medium))
                            Text("Filed")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                    .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        
        VStack(spacing: 20) {
            SettlementCard(
                settlement: Settlement.preview,
                isClaimed: false
            ) {
                print("Claimed!")
            }
            
            HStack(spacing: 12) {
                CompactSettlementCard(settlement: Settlement.preview, isClaimed: false)
                CompactSettlementCard(settlement: Settlement.preview, isClaimed: true)
            }
        }
        .padding()
    }
}

// Preview helper
extension Settlement {
    static var preview: Settlement {
        Settlement(
            id: UUID(),
            sourceId: "preview-1",
            name: "23andMe - Data Breach Class Action Settlement",
            companyName: "23andMe",
            payoutMin: 100,
            payoutMax: 10000,
            deadline: "2026-02-17",
            daysLeft: 21,
            description: "You may be included in this settlement if you were a 23andMe customer.",
            requiresProof: false,
            claimUrl: "https://example.com",
            sourceUrl: "https://classaction.org",
            isFeatured: true,
            logoUrl: nil,
            createdAt: "2026-01-26T00:00:00Z",
            updatedAt: "2026-01-26T00:00:00Z",
            caseType: "Data Breach",
            payoutDisplayDB: "Up to $10,000",
            aboutText: "23andMe experienced a data breach in 2023 that exposed genetic and ancestry data. This settlement resolves class claims over the incident.",
            eligibilityText: "You may be included if you were a 23andMe customer whose data was compromised.",
            category: "Privacy",
            isMajorBrand: true
        )
    }
}
