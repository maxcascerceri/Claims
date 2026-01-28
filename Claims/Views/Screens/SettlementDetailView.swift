//
//  SettlementDetailView.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct SettlementDetailView: View {
    let settlement: Settlement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var viewModel: SettlementsViewModel
    @State private var showDidFilePrompt = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.bottom, 20)
                        
                        badgesSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        
                        VStack(spacing: 16) {
                            detailsCard
                            eligibilityCard
                            if viewModel.isClaimed(settlement), let submitted = viewModel.submittedDate(for: settlement) {
                                claimDateCard(submitted: submitted)
                            } else {
                                deadlineCard
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 200)
                    }
                    .padding(.top, 8)
                }
                
                // Bottom CTA
                bottomCTA
            }
            .id(viewModel.isClaimed(settlement))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active,
                   viewModel.lastSettlementOpenedForClaim == settlement.id {
                    showDidFilePrompt = true
                }
            }
            .overlay {
                if showDidFilePrompt {
                    didFileOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Asset.bodyGray)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            LogoView(
                iconName: settlement.logoName,
                color: settlement.logoColor,
                size: 88,
                url: viewModel.effectiveLogoURL(for: settlement)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 88 * 0.24, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            
            VStack(spacing: 10) {
                Text(settlement.companyName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Asset.bodyGray)
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Text(settlement.payoutDisplay)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Asset.accentGreen)
                
                Text(settlement.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Asset.bodyGray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        HStack(spacing: 8) {
            if viewModel.isClaimed(settlement), let submitted = viewModel.submittedDate(for: settlement) {
                MinimalBadge(
                    text: "Submitted \(submitted.formatted(date: .abbreviated, time: .omitted))",
                    icon: "checkmark.circle.fill",
                    color: Asset.accentGreen
                )
            }
            if settlement.noProofRequired {
                MinimalBadge(text: "No Proof Needed", icon: "checkmark.seal.fill", color: .green)
            }
            if settlement.daysRemaining <= 14 {
                MinimalBadge(text: "Closing Soon", icon: "clock.fill", color: .orange)
            }
            if settlement.isUncapped {
                MinimalBadge(text: "Uncapped", icon: "infinity", color: .purple)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionIconView.details
                Text("About")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Asset.titleGray)
                Spacer()
                if let caseType = settlement.caseType, !caseType.isEmpty {
                    Text(caseType)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(settlement.settlementCategory.badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(settlement.settlementCategory.badgeColor.opacity(0.12))
                        )
                }
            }
            
            Text(settlement.aboutContent ?? "No summary available. Check the official settlement website for details.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Asset.bodyGray)
                .lineSpacing(5)
                .tracking(0.2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(cardBackground)
    }
    
    // MARK: - Eligibility Card
    
    private var eligibilityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SectionIconView.eligibility
                Text("Eligibility")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Asset.titleGray)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(settlement.eligibility.enumerated()), id: \.offset) { _, requirement in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Asset.accentGreen)
                        
                        Text(requirement)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Asset.bodyGray)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(cardBackground)
    }
    
    // MARK: - Deadline Card
    
    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SectionIconView.deadline
                Text("Deadline")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Asset.titleGray)
            }
            
            HStack(alignment: .center, spacing: 12) {
                deadlineDateView
                Spacer()
                Text("\(settlement.daysRemaining) days left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(daysLeftPillColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(cardBackground)
    }
    
    private var daysLeftPillColor: Color {
        if settlement.daysRemaining <= 3 { return .red }
        if settlement.daysRemaining <= 7 { return .orange }
        return Color(.systemGray)
    }
    
    private var deadlineDateView: some View {
        DeadlineDateView(date: settlement.deadlineDate ?? Calendar.current.date(byAdding: .day, value: settlement.daysRemaining, to: Date()) ?? Date())
    }
    
    // MARK: - Claim Date Card (filed claims)
    
    private func claimDateCard(submitted: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SectionIconView.eligibility
                Text("Claim Date")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Asset.titleGray)
            }
            
            DeadlineDateView(date: submitted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(cardBackground)
    }
    
    // MARK: - Bottom CTA
    
    private var bottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground).opacity(0),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            
            VStack(spacing: 12) {
                Button {
                    Haptics.light()
                    shareSettlement()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share With a Friend")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Asset.bodyGray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(.systemGray4).opacity(0.5), lineWidth: 0.5)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                if viewModel.isClaimed(settlement) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Filed")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Asset.accentGreen)
                    )
                } else {
                    Button {
                        Haptics.success()
                        viewModel.lastSettlementOpenedForClaim = settlement.id
                        if let url = URL(string: settlement.externalURL) {
                            openURL(url)
                        }
                    } label: {
                        Text("File Claim")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Asset.accentGreen)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(.systemGray5).opacity(0.6), lineWidth: 0.5)
            )
    }
    
    private func shareSettlement() {
        // Share functionality would go here
    }
    
    // MARK: - Did you file? overlay
    
    private var didFileOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { }
            
            VStack(spacing: 28) {
                Text("Did you file the claim?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text("We’ll mark \(settlement.companyName) as filed and add it to your wallet.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Asset.bodyGray)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    Button {
                        Haptics.light()
                        viewModel.clearLastOpenedForClaim()
                        showDidFilePrompt = false
                    } label: {
                        Text("Not yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        Haptics.success()
                        viewModel.markAsClaimed(settlement)
                        showDidFilePrompt = false
                    } label: {
                        Text("Yes, I filed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Asset.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(28)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 24, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(.systemGray5).opacity(0.6), lineWidth: 0.5)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Section icons (reference design: folder, green check square, calendar)

private enum SectionIconView {
    static var details: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.2))
            .frame(width: 28, height: 28)
    }
    
    static var eligibility: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.1, green: 0.65, blue: 0.25))
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white, lineWidth: 1.5)
        )
        .frame(width: 28, height: 28)
    }
    
    static var deadline: some View {
        Image(systemName: "calendar")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color(.systemGray))
            .frame(width: 28, height: 28)
    }
}

// MARK: - Deadline date (day emphasized: "Feb 3, 2026")

private struct DeadlineDateView: View {
    let date: Date
    
    private var month: String { date.formatted(.dateTime.month(.abbreviated)) }
    private var dayStr: String { date.formatted(.dateTime.day()) }
    private var year: String { date.formatted(.dateTime.year()) }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(month + " ")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Asset.bodyGray)
            Text(dayStr)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Asset.bodyGray)
            Text(", " + year)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Asset.bodyGray)
        }
    }
}

// MARK: - Minimal Badge

private struct MinimalBadge: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }
}

#Preview {
    SettlementDetailView(settlement: Settlement.preview)
        .environmentObject(SettlementsViewModel())
}
