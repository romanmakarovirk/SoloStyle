//
//  SettingsView.swift
//  SoloStyle
//
//  Settings with improved design and interactions
//

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showingLanguageSheet = false
    @State private var showingHelpCenter = false
    @State private var showingContactSheet = false
    @State private var showingPrivacyPolicy = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: Design.Spacing.l) {
                        // Settings Sections
                        settingsSection(title: L.preferences) {
                            toggleRow(
                                icon: "bell.badge",
                                iconColor: .red,
                                title: L.notifications,
                                subtitle: L.appointmentReminders,
                                isOn: $notificationsEnabled
                            )

                            Divider().padding(.leading, 52)

                            toggleRow(
                                icon: "calendar",
                                iconColor: .blue,
                                title: L.calendarSync,
                                subtitle: L.syncWithIOSCalendar,
                                isOn: $calendarSyncEnabled
                            )

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "globe",
                                iconColor: .green,
                                title: L.language,
                                value: currentLanguageName
                            ) {
                                HapticManager.selection()
                                showingLanguageSheet = true
                            }
                        }
                        .animateOnAppear(delay: 0.2)

                        settingsSection(title: L.data) {
                            settingsRow(
                                icon: "square.and.arrow.up",
                                iconColor: .blue,
                                title: L.exportData,
                                value: nil
                            ) {
                                HapticManager.selection()
                            }
                        }
                        .animateOnAppear(delay: 0.3)

                        settingsSection(title: L.support) {
                            settingsRow(
                                icon: "questionmark.circle",
                                iconColor: .orange,
                                title: L.helpCenter,
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingHelpCenter = true
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "envelope.fill",
                                iconColor: .blue,
                                title: L.contactUs,
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingContactSheet = true
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: L.rateApp,
                                value: nil
                            ) {
                                HapticManager.selection()
                                requestAppReview()
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "doc.text",
                                iconColor: .gray,
                                title: L.privacyPolicy,
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingPrivacyPolicy = true
                            }
                        }
                        .animateOnAppear(delay: 0.5)

                        #if DEBUG
                        settingsSection(title: L.developer) {
                            Button {
                                HapticManager.notification(.warning)
                                hasCompletedOnboarding = false
                            } label: {
                                HStack(spacing: Design.Spacing.m) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.red)
                                    }

                                    Text(L.resetOnboarding)
                                        .font(Design.Typography.body)
                                        .foregroundStyle(.red)

                                    Spacer()
                                }
                                .padding(Design.Spacing.m)
                            }
                        }
                        .animateOnAppear(delay: 0.6)
                        #endif

                        // Footer
                        footerSection
                            .animateOnAppear(delay: 0.7)
                    }
                    .padding(Design.Spacing.m)
                    .padding(.bottom, Design.Spacing.xxl * 2)
                }
                .scrollBounceBehavior(.always)
            }
            .navigationTitle(L.settings)
            .sheet(isPresented: $showingLanguageSheet) {
                LanguageSelectionView()
            }
            .sheet(isPresented: $showingHelpCenter) {
                HelpCenterView()
            }
            .sheet(isPresented: $showingContactSheet) {
                ContactUsView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .onChange(of: notificationsEnabled) { _, enabled in
                Task {
                    if enabled {
                        let granted = await NotificationManager.shared.requestPermission()
                        if !granted {
                            await MainActor.run { notificationsEnabled = false }
                        }
                    } else {
                        NotificationManager.shared.cancelAllReminders()
                    }
                }
            }
        }
    }

    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    private var currentLanguageName: String {
        switch lang.language {
        case "ru": return "Русский"
        default: return "English"
        }
    }

    // MARK: - Settings Section

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Text(title.uppercased())
                .font(Design.Typography.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(Design.Colors.textTertiary)
                .padding(.leading, Design.Spacing.xs)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    // MARK: - Settings Row

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Design.Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(Design.Colors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .padding(Design.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toggle Row

    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: Design.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Design.Typography.body)
                    .foregroundStyle(Design.Colors.textPrimary)
                Text(subtitle)
                    .font(Design.Typography.caption1)
                    .foregroundStyle(Design.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Design.Colors.accentPrimary)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    HapticManager.selection()
                }
        }
        .padding(Design.Spacing.m)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: Design.Spacing.s) {
            Image(systemName: "scissors")
                .font(.system(size: 32))
                .foregroundStyle(Design.Colors.textTertiary.opacity(0.5))

            Text("SoloStyle")
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textSecondary)

            Text("Version 1.0.0 (Build 1)")
                .font(Design.Typography.caption1)
                .foregroundStyle(Design.Colors.textTertiary)

            Text(L.appFooter)
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
                .padding(.top, Design.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.l)
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.m) {
                        ForEach(L.faqItems, id: \.0) { question, answer in
                            GlassCard {
                                VStack(alignment: .leading, spacing: Design.Spacing.s) {
                                    HStack {
                                        Image(systemName: "questionmark.circle.fill")
                                            .foregroundStyle(Design.Colors.accentPrimary)
                                        Text(question)
                                            .font(Design.Typography.headline)
                                            .foregroundStyle(Design.Colors.textPrimary)
                                    }

                                    Text(answer)
                                        .font(Design.Typography.body)
                                        .foregroundStyle(Design.Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(Design.Spacing.m)
                }
            }
            .navigationTitle(L.helpCenter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Contact Us View

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: Design.Spacing.l) {
                    Spacer()

                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Design.Colors.accentPrimary)

                    VStack(spacing: Design.Spacing.s) {
                        Text(L.needHelp)
                            .font(Design.Typography.title2)

                        Text(L.contactDescription)
                            .font(Design.Typography.body)
                            .foregroundStyle(Design.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Design.Spacing.xl)
                    }

                    VStack(spacing: Design.Spacing.m) {
                        GlassButton(title: L.emailSupport, icon: "envelope.fill", isFullWidth: true) {
                            if let url = InputValidator.safeEmailURL("support@solostyle.app") {
                                UIApplication.shared.open(url)
                            }
                        }

                        GlassButton(title: L.visitWebsite, icon: "safari.fill", style: .secondary, isFullWidth: true) {
                            if let url = URL(string: "https://solostyle.app") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.m)

                    Spacer()
                }
            }
            .navigationTitle(L.contactUs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.l) {
                        Group {
                            policySection(title: L.ppDataCollection, content: L.ppDataCollectionText)
                            policySection(title: L.ppLocalStorage, content: L.ppLocalStorageText)
                            policySection(title: L.ppNoSharing, content: L.ppNoSharingText)
                            policySection(title: L.ppAnalytics, content: L.ppAnalyticsText)
                            policySection(title: L.ppContact, content: L.ppContactText)
                        }
                    }
                    .padding(Design.Spacing.m)
                }
            }
            .navigationTitle(L.privacyPolicy)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(title)
                .font(Design.Typography.headline)
                .foregroundStyle(Design.Colors.textPrimary)

            Text(content)
                .font(Design.Typography.body)
                .foregroundStyle(Design.Colors.textSecondary)
        }
    }
}

// MARK: - Language Selection View

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    private let languages = [
        ("ru", "Русский", "🇷🇺"),
        ("en", "English", "🇺🇸")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                List {
                    ForEach(languages, id: \.0) { code, name, flag in
                        Button {
                            HapticManager.selection()
                            lang.language = code
                            UserDefaults.standard.set([code], forKey: "AppleLanguages")
                            dismiss()
                        } label: {
                            HStack {
                                Text(flag)
                                    .font(.system(size: 28))

                                Text(name)
                                    .font(Design.Typography.body)
                                    .foregroundStyle(Design.Colors.textPrimary)

                                Spacer()

                                if lang.language == code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Design.Colors.accentPrimary)
                                }
                            }
                            .padding(.vertical, Design.Spacing.xs)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L.language)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
