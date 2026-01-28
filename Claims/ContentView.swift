//
//  ContentView.swift
//  Claims
//
//  Created by Max Cascerceri on 1/26/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SettlementsViewModel()
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case wallet
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .wallet:
                    WalletView(onSwitchToHome: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = .home
                        }
                    })
                }
            }
            .environmentObject(viewModel)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == .home
            ) {
                Haptics.selection()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTab = .home
                }
            }
            
            TabBarButton(
                icon: "wallet.pass.fill",
                title: "Wallet",
                isSelected: selectedTab == .wallet
            ) {
                Haptics.selection()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTab = .wallet
                }
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary.opacity(0.6))
                
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.0 : 0.95)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
