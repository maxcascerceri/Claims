//
//  GetStartedCard.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct GetStartedCard: View {
    let availableMoney: Int
    let claimsCount: Int
    
    @State private var displayedAmount: Int = 0
    
    private static let countUpDuration: Double = 1.2
    private static let countUpSteps = 50
    
    private var baseGreen: Color {
        Asset.accentGreen
    }
    
    private var darkerGreenOval: Color {
        Color(red: 0.1, green: 0.45, blue: 0.28)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text("AVAILABLE TO CLAIM")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .textCase(.uppercase)
            
            Text("$\(displayedAmount.formatted())")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(.white)
            
            Text(claimsCount == 1 ? "from 1 open settlement" : "from \(claimsCount) open settlements")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
        .onAppear {
            startCountUp()
        }
        .onChange(of: availableMoney) { _, newValue in
            displayedAmount = 0
            startCountUp(target: newValue)
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            baseGreen
            
            Ellipse()
                .fill(darkerGreenOval.opacity(0.35))
                .frame(width: 180, height: 90)
                .blur(radius: 20)
                .offset(x: -70, y: 30)
            
            Ellipse()
                .fill(darkerGreenOval.opacity(0.35))
                .frame(width: 180, height: 90)
                .blur(radius: 20)
                .offset(x: 70, y: 30)
        }
    }
    
    private func startCountUp(target: Int? = nil) {
        let targetValue = target ?? availableMoney
        guard targetValue > 0 else {
            displayedAmount = 0
            return
        }
        displayedAmount = 0
        let duration = Self.countUpDuration
        let start = CFAbsoluteTimeGetCurrent()
        
        Task { @MainActor in
            var lastHapticValue = -1
            for step in 0..<Self.countUpSteps {
                try? await Task.sleep(nanoseconds: UInt64((duration / Double(Self.countUpSteps)) * 1_000_000_000))
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let progress = min(1.0, elapsed / duration)
                let newValue = Int(Double(targetValue) * progress)
                displayedAmount = newValue
                if newValue != lastHapticValue {
                    lastHapticValue = newValue
                    Haptics.selection()
                }
            }
            displayedAmount = targetValue
            if targetValue != lastHapticValue {
                Haptics.selection()
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        
        GetStartedCard(
            availableMoney: 18651,
            claimsCount: 50
        )
        .padding()
    }
}
