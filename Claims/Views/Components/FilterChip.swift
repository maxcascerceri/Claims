//
//  FilterChip.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct FilterChip: View {
    let category: SettlementCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(category.rawValue)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Asset.accentGreen : Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct FilterChipsRow: View {
    @Binding var selectedCategory: SettlementCategory
    let categories: [SettlementCategory]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    FilterChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.trailing, 20)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        FilterChipsRow(
            selectedCategory: .constant(.all),
            categories: [.all, .noProof, .privacy, .finance, .consumer]
        )
    }
    .padding(.vertical)
    .background(Color(.systemGray6))
}
