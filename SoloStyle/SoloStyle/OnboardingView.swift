//
//  OnboardingView.swift
//  SoloStyle
//
//  Onboarding flow with premium animations
//

import AuthenticationServices
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var authManager = AuthManager.shared

    @State private var currentStep = 0
    @State private var name = ""
    @State private var businessName = ""
    @State private var isAnimating = false
    @State private var confettiTrigger = false

    // If authenticated master: profile setup (steps 0,1), else: login screen
    private var isMasterOnboarding: Bool {
        authManager.isAuthenticated && authManager.selectedRole == .master
    }

    private var totalSteps: Int { isMasterOnboarding ? 2 : 1 }

    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedGradientBackground()
                .ignoresSafeArea()

            if isMasterOnboarding {
                // Master profile setup flow
                masterOnboardingContent
            } else {
                // Telegram login screen
                telegramLoginContent
            }

            // Confetti overlay
            if confettiTrigger {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            isAnimating = true
            // Pre-fill name from Telegram if available
            if let user = authManager.currentUser, name.isEmpty {
                name = user.firstName
                if let lastName = user.lastName {
                    name += " \(lastName)"
                }
            }
        }
    }

    // MARK: - Telegram Login Content

    private var telegramLoginContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Design.Spacing.xl) {
                Spacer()

                // Animated Logo
                AnimatedLogoView()
                    .animateOnAppear(delay: 0.1)

                VStack(spacing: Design.Spacing.m) {
                    Text(L.welcomeTitle)
                        .font(Design.Typography.largeTitle)
                        .multilineTextAlignment(.center)
                        .animateOnAppear(delay: 0.2)

                    Text(L.welcomeSubtitle)
                        .font(Design.Typography.body)
                        .foregroundStyle(Design.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .animateOnAppear(delay: 0.3)
                }

                VStack(alignment: .leading, spacing: Design.Spacing.m) {
                    AnimatedFeatureItem(icon: "calendar", text: L.featureManage, delay: 0.4)
                    AnimatedFeatureItem(icon: "bell.badge", text: L.featureReminders, delay: 0.5)
                    AnimatedFeatureItem(icon: "link", text: L.featureBooking, delay: 0.6)
                }
                .padding(.horizontal, Design.Spacing.xl)

                Spacer()
            }
            .padding(Design.Spacing.m)

            // Login buttons
            VStack(spacing: Design.Spacing.s) {
                if authManager.isAuthenticating {
                    HStack(spacing: Design.Spacing.s) {
                        ProgressView()
                            .tint(.white)
                        Text(L.waitingForTelegram)
                            .font(Design.Typography.subheadline)
                            .foregroundStyle(Design.Colors.textSecondary)
                    }
                    .padding(.vertical, Design.Spacing.m)
                } else {
                    GlassButton(title: L.continueWithTelegram, icon: "paperplane.fill") {
                        HapticManager.impact(.medium)
                        Task { await authManager.startTelegramAuth() }
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Design.Colors.textSecondary.opacity(0.3))
                            .frame(height: 1)
                        Text(L.orDivider)
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textSecondary)
                        Rectangle()
                            .fill(Design.Colors.textSecondary.opacity(0.3))
                            .frame(height: 1)
                    }

                    // Apple Sign-In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task {
                            await authManager.handleAppleSignIn(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(Design.Radius.m)
                }

                if let error = authManager.authError {
                    Text(error)
                        .font(Design.Typography.caption1)
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .padding(Design.Spacing.m)
            .animation(Design.Animation.smooth, value: authManager.isAuthenticating)
        }
    }

    // MARK: - Master Onboarding Content

    private var masterOnboardingContent: some View {
        VStack(spacing: 0) {
            AnimatedProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.m)

            ZStack {
                if currentStep == 0 {
                    profileStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    completeStep
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(Design.Animation.smooth, value: currentStep)

            HStack(spacing: Design.Spacing.m) {
                if currentStep > 0 {
                    GlassButton(title: L.back, icon: "chevron.left", style: .secondary) {
                        HapticManager.impact(.light)
                        withAnimation(Design.Animation.smooth) { currentStep -= 1 }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    GlassButton(title: L.continueText, icon: "arrow.right") {
                        HapticManager.impact(.medium)
                        withAnimation(Design.Animation.smooth) { currentStep += 1 }
                    }
                    .disabled(name.isEmpty)
                } else {
                    GlassButton(title: L.startUsingSoloStyle, icon: "sparkles") {
                        HapticManager.notification(.success)
                        confettiTrigger = true
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            completeOnboarding()
                        }
                    }
                }
            }
            .padding(Design.Spacing.m)
            .animation(Design.Animation.smooth, value: currentStep)
        }
    }

    // MARK: - Profile Step

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.l) {
                VStack(spacing: Design.Spacing.s) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Design.Colors.accentPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Design.Colors.accentPrimary)
                            .symbolEffect(.bounce, options: .repeating.speed(0.3), value: isAnimating)
                    }
                    .animateOnAppear(delay: 0.1)

                    Text(L.createYourProfile)
                        .font(Design.Typography.title2)
                        .animateOnAppear(delay: 0.2)

                    Text(L.tellAboutYourself)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textSecondary)
                        .animateOnAppear(delay: 0.3)
                }
                .padding(.top, Design.Spacing.l)

                // Animated avatar placeholder
                AvatarPlaceholder(name: name)
                    .animateOnAppear(delay: 0.4)

                VStack(spacing: Design.Spacing.m) {
                    FormField(title: L.yourName, placeholder: L.namePlaceholder, text: $name, icon: "person")
                        .animateOnAppear(delay: 0.5)

                    FormField(title: L.businessNameOptional, placeholder: L.businessPlaceholder, text: $businessName, icon: "building.2")
                        .animateOnAppear(delay: 0.6)
                }
                .padding(.horizontal, Design.Spacing.m)

                // Tip card
                if !name.isEmpty {
                    TipCard(
                        icon: "lightbulb.fill",
                        text: L.profileTip
                    )
                    .padding(.horizontal, Design.Spacing.m)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(spacing: Design.Spacing.xl) {
            Spacer()

            // Success animation
            SuccessCheckmark()
                .animateOnAppear(delay: 0.1)

            VStack(spacing: Design.Spacing.m) {
                Text(L.allSet)
                    .font(Design.Typography.largeTitle)
                    .animateOnAppear(delay: 0.3)

                Text(L.allSetSubtitle)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.l)
                    .animateOnAppear(delay: 0.4)
            }

            // Summary card
            GlassCard {
                VStack(spacing: Design.Spacing.m) {
                    ProfileSummaryRow(icon: "person.fill", label: L.name, value: name)

                    if !businessName.isEmpty {
                        Divider()
                            .background(Design.Colors.glassTint)
                        ProfileSummaryRow(icon: "building.2.fill", label: L.businessName, value: businessName)
                    }
                }
            }
            .padding(.horizontal, Design.Spacing.m)
            .animateOnAppear(delay: 0.5)

            // Quick tips
            QuickStartTips()
                .padding(.horizontal, Design.Spacing.m)
                .animateOnAppear(delay: 0.6)

            Spacer()
        }
        .padding(Design.Spacing.m)
    }

    // MARK: - Helpers

    private func completeOnboarding() {
        let master = Master(name: name, businessName: businessName.isEmpty ? nil : businessName)
        modelContext.insert(master)
        hasCompletedOnboarding = true
    }
}

// MARK: - Animated Components

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Design.Colors.backgroundPrimary,
                Design.Colors.backgroundSecondary,
                Design.Colors.accentPrimary.opacity(0.05)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

struct AnimatedProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: Design.Spacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Design.Colors.accentPrimary : Design.Colors.backgroundSecondary)
                    .frame(height: 4)
                    .overlay(
                        Capsule()
                            .fill(Design.Colors.accentPrimary)
                            .scaleEffect(x: step == currentStep ? 1 : 0, anchor: .leading)
                    )
                    .animation(Design.Animation.smooth.delay(Double(step) * 0.1), value: currentStep)
            }
        }
    }
}

struct AnimatedLogoView: View {
    @State private var rotation: Double = 0

    var body: some View {
        // Liquid Glass logo - no flying circles
        Image(systemName: "scissors")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(Design.Colors.accentPrimary)
            .rotationEffect(.degrees(rotation))
            .frame(width: 140, height: 140)
            .soloGlass(tint: Color.blue.opacity(0.2), shape: .roundedRect(32))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    rotation = -15
                }
            }
    }
}

struct AnimatedFeatureItem: View {
    let icon: String
    let text: String
    let delay: Double

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Design.Colors.accentPrimary)
                .frame(width: 40, height: 40)
                .soloGlass(tint: Color.blue.opacity(0.15), shape: .circle)

            Text(text)
                .font(Design.Typography.body)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Design.Colors.accentSuccess)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.5)
        }
        .padding(Design.Spacing.s)
        .soloGlass(tint: Color.white.opacity(0.05), shape: .roundedRect(Design.Radius.m))
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(Design.Animation.smooth.delay(delay)) {
                isVisible = true
            }
        }
    }
}

struct AvatarPlaceholder: View {
    let name: String

    var body: some View {
        ZStack {
            if name.isEmpty {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 100, height: 100)
        .soloGlass(tint: Color.blue.opacity(0.3), shape: .circle)
        .animation(Design.Animation.smooth, value: name)
    }
}

struct SuccessCheckmark: View {
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        // Clean success checkmark with Liquid Glass - no flying rings
        Image(systemName: "checkmark")
            .font(.system(size: 50, weight: .bold))
            .foregroundStyle(Design.Colors.accentSuccess)
            .frame(width: 120, height: 120)
            .soloGlass(tint: Color.green.opacity(0.2), shape: .circle)
            .scaleEffect(checkmarkScale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    checkmarkScale = 1.0
                }
            }
    }
}

struct TipCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Design.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.yellow)

            Text(text)
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textSecondary)
        }
        .padding(Design.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.m)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

struct ProfileSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Design.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Design.Colors.accentPrimary)
                .frame(width: 24)

            Text(label)
                .font(Design.Typography.subheadline)
                .foregroundStyle(Design.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textPrimary)
        }
    }
}

struct QuickStartTips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(L.quickStart)
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textTertiary)

            HStack(spacing: Design.Spacing.s) {
                QuickTipChip(icon: "plus.circle", text: L.tipAddServices)
                QuickTipChip(icon: "person.badge.plus", text: L.tipAddClients)
                QuickTipChip(icon: "link", text: L.tipShareLink)
            }
        }
    }
}

struct QuickTipChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Design.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(Design.Typography.caption2)
        }
        .foregroundStyle(Design.Colors.accentPrimary)
        .padding(.horizontal, Design.Spacing.s)
        .padding(.vertical, Design.Spacing.xs)
        .background(
            Capsule()
                .fill(Design.Colors.accentPrimary.opacity(0.1))
        )
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
    }

    private func createParticles(in size: CGSize) {
        guard particles.isEmpty else { return } // Prevent double invocation
        let colors: [Color] = [.blue, .green, .yellow, .orange, .pink, .purple]
        for i in 0..<50 {
            let particle = ConfettiParticle(
                id: i,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                opacity: 1.0
            )
            particles.append(particle)

            withAnimation(.easeOut(duration: Double.random(in: 1.5...3.0)).delay(Double(i) * 0.02)) {
                particles[i].position.y = size.height + 50
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}

#Preview {
    OnboardingView()
        .modelContainer(for: Master.self, inMemory: true)
}
