//
//  BadgeView.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct BadgeView: View {
    let text: String
    let style: BadgeStyle
    
    enum BadgeStyle {
        case noProof
        case closingSoon
        case uncapped
        case neutral
        
        var backgroundColor: Color {
            switch self {
            case .noProof:
                return Color(red: 0.1, green: 0.7, blue: 0.3).opacity(0.12)
            case .closingSoon:
                return Color.orange.opacity(0.12)
            case .uncapped:
                return Color.purple.opacity(0.12)
            case .neutral:
                return Color(.systemGray5)
            }
        }
        
        var textColor: Color {
            switch self {
            case .noProof:
                return Color(red: 0.1, green: 0.6, blue: 0.3)
            case .closingSoon:
                return .orange
            case .uncapped:
                return .purple
            case .neutral:
                return .secondary
            }
        }
        
        var icon: String? {
            switch self {
            case .noProof: return "checkmark.circle.fill"
            case .closingSoon: return "clock.fill"
            case .uncapped: return "infinity"
            case .neutral: return nil
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if let icon = style.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(style.textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(style.backgroundColor)
        .clipShape(Capsule())
    }
}

// Convenience initializers for common badges
extension BadgeView {
    static var noProof: BadgeView {
        BadgeView(text: "No Proof", style: .noProof)
    }
    
    static var closingSoon: BadgeView {
        BadgeView(text: "Closing Soon", style: .closingSoon)
    }
    
    static var uncapped: BadgeView {
        BadgeView(text: "Uncapped", style: .uncapped)
    }
}

#Preview {
    VStack(spacing: 16) {
        BadgeView.noProof
        BadgeView.closingSoon
        BadgeView.uncapped
        BadgeView(text: "Privacy", style: .neutral)
    }
    .padding()
}
