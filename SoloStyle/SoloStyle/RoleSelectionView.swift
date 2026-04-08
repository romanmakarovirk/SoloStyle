//
//  RoleSelectionView.swift
//  SoloStyle
//
//  Role selection after Telegram auth — Master or Client
//

import SwiftUI

struct RoleSelectionView: View {
    @State private var authManager = AuthManager.shared
    @State private var selectedCard: UserRole?
    @State private var appear = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Welcome text
                VStack(spacing: Design.Spacing.s) {
                    if let user = authManager.currentUser {
                        Text("\(L.welcome), \(user.firstName)!")
                            .font(Design.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                    Text(L.howDoYouWantToUseApp)
                        .font(Design.Typography.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .padding(.bottom, Design.Spacing.xl)

                // Role cards
                VStack(spacing: Design.Spacing.m) {
                    // Master card
                    RoleCard(
                        icon: "scissors",
                        title: L.roleMaster,
                        subtitle: L.roleMasterDescription,
                        gradient: [Color.blue, Color.purple],
                        isSelected: selectedCard == .master
                    ) {
                        withAnimation(Design.Animation.smooth) {
                            selectedCard = .master
                        }
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 30)

                    // Client card
                    RoleCard(
                        icon: "sparkles",
                        title: L.roleClient,
                        subtitle: L.roleClientDescription,
                        gradient: [Color.orange, Color.pink],
                        isSelected: selectedCard == .client
                    ) {
                        withAnimation(Design.Animation.smooth) {
                            selectedCard = .client
                        }
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 40)
                }
                .padding(.horizontal, Design.Spacing.l)

                Spacer()

                // Continue button
                if let role = selectedCard {
                    Button {
                        Task {
                            await authManager.selectRole(role)
                        }
                    } label: {
                        HStack(spacing: Design.Spacing.s) {
                            Text(L.continueButton)
                                .font(Design.Typography.headline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.m)
                        .background(
                            LinearGradient(
                                colors: role == .master ? [.blue, .purple] : [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.l))
                    }
                    .padding(.horizontal, Design.Spacing.l)
                    .padding(.bottom, Design.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appear = true
            }
        }
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void

    private var primaryColor: Color { gradient.first ?? .blue }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.m) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Design.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? primaryColor : .white.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 20, height: 20)

                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(Design.Spacing.m)
            .soloGlass(
                tint: isSelected ? primaryColor.opacity(0.15) : Color.white.opacity(0.05),
                shape: .roundedRect(Design.Radius.l)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.l)
                    .strokeBorder(
                        isSelected ? primaryColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(Design.Animation.smooth, value: isSelected)
    }
}
