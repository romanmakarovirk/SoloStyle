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
    private let statsCache = StatsCache.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("appLanguage") private var appLanguage = "en"
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
                        // Quick Stats
                        quickStatsSection
                            .animateOnAppear(delay: 0.1)

                        // Settings Sections
                        settingsSection(title: "Preferences") {
                            toggleRow(
                                icon: "bell.badge",
                                iconColor: .red,
                                title: "Notifications",
                                subtitle: "Appointment reminders",
                                isOn: $notificationsEnabled
                            )

                            Divider().padding(.leading, 52)

                            toggleRow(
                                icon: "calendar",
                                iconColor: .blue,
                                title: "Calendar Sync",
                                subtitle: "Sync with iOS Calendar",
                                isOn: $calendarSyncEnabled
                            )

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "globe",
                                iconColor: .green,
                                title: "Language",
                                value: currentLanguageName
                            ) {
                                HapticManager.selection()
                                showingLanguageSheet = true
                            }
                        }
                        .animateOnAppear(delay: 0.2)

                        settingsSection(title: "Data") {
                            settingsRow(
                                icon: "square.and.arrow.up",
                                iconColor: .blue,
                                title: "Export Data",
                                value: nil
                            ) {
                                HapticManager.selection()
                            }
                        }
                        .animateOnAppear(delay: 0.3)

                        settingsSection(title: "Support") {
                            settingsRow(
                                icon: "questionmark.circle",
                                iconColor: .orange,
                                title: "Help Center",
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingHelpCenter = true
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "envelope.fill",
                                iconColor: .blue,
                                title: "Contact Us",
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingContactSheet = true
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Rate App",
                                value: nil
                            ) {
                                HapticManager.selection()
                                requestAppReview()
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(
                                icon: "doc.text",
                                iconColor: .gray,
                                title: "Privacy Policy",
                                value: nil
                            ) {
                                HapticManager.selection()
                                showingPrivacyPolicy = true
                            }
                        }
                        .animateOnAppear(delay: 0.5)

                        #if DEBUG
                        settingsSection(title: "Developer") {
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

                                    Text("Reset Onboarding")
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
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLanguageSheet) {
                LanguageSelectionView(selectedLanguage: $appLanguage)
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
        switch appLanguage {
        case "ru": return "Русский"
        default: return "English"
        }
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        HStack(spacing: Design.Spacing.s) {
            QuickStatCard(icon: "person.2.fill", value: "\(statsCache.clientCount)", label: "Clients", limit: nil, color: .blue)
            QuickStatCard(icon: "calendar.badge.checkmark", value: "\(statsCache.thisMonthAppointments)", label: "This Month", limit: nil, color: .green)
            QuickStatCard(icon: "scissors", value: "\(statsCache.activeServicesCount)", label: "Services", limit: nil, color: .purple)
        }
        .onAppear {
            statsCache.refreshIfNeeded(context: modelContext)
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

            Text("Made with love for solo professionals")
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
                .padding(.top, Design.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.l)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let limit: String?
    let color: Color

    var body: some View {
        GlassCard(padding: Design.Spacing.s) {
            VStack(spacing: Design.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                HStack(spacing: 2) {
                    Text(value)
                        .font(Design.Typography.title3)
                        .foregroundStyle(Design.Colors.textPrimary)

                    if let limit {
                        Text(limit)
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }

                Text(label)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqItems = [
        ("How do I add a new client?", "Go to the Clients tab and tap the + button to add a new client with their contact information."),
        ("How do I schedule an appointment?", "Navigate to the Calendar tab, select a date, and tap the + button to create a new appointment."),
        ("How do I share my booking link?", "Go to your Profile tab and tap 'Share' on your booking link card to share it with clients."),
        ("How do I add a service?", "Go to your Profile tab, scroll to Services section and tap + to add a new service with price and duration."),
        ("How do I mark an appointment as completed?", "Tap on the appointment to expand it, then tap 'Complete' to mark it as done.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.m) {
                        ForEach(faqItems, id: \.0) { question, answer in
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
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
                        Text("Need Help?")
                            .font(Design.Typography.title2)

                        Text("We're here to help! Contact us through any of the following channels.")
                            .font(Design.Typography.body)
                            .foregroundStyle(Design.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Design.Spacing.xl)
                    }

                    VStack(spacing: Design.Spacing.m) {
                        GlassButton(title: "Email Support", icon: "envelope.fill", isFullWidth: true) {
                            if let url = InputValidator.safeEmailURL("support@solostyle.app") {
                                UIApplication.shared.open(url)
                            }
                        }

                        GlassButton(title: "Visit Website", icon: "safari.fill", style: .secondary, isFullWidth: true) {
                            if let url = URL(string: "https://solostyle.app") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.m)

                    Spacer()
                }
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
                            policySection(
                                title: "Data Collection",
                                content: "SoloStyle stores all your data locally on your device. We do not collect or transmit any personal information to external servers."
                            )

                            policySection(
                                title: "Local Storage",
                                content: "All client information, appointments, and settings are stored securely on your device using Apple's SwiftData framework."
                            )

                            policySection(
                                title: "No Third-Party Sharing",
                                content: "We do not share your data with any third parties. Your business information remains private and under your control."
                            )

                            policySection(
                                title: "Analytics",
                                content: "We may collect anonymous usage analytics to improve the app experience. This data cannot be used to identify you."
                            )

                            policySection(
                                title: "Contact",
                                content: "If you have any questions about our privacy practices, please contact us at privacy@solostyle.app"
                            )
                        }
                    }
                    .padding(Design.Spacing.m)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
    @Binding var selectedLanguage: String

    private let languages = [
        ("en", "English", "🇺🇸"),
        ("ru", "Русский", "🇷🇺")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                List {
                    ForEach(languages, id: \.0) { code, name, flag in
                        Button {
                            HapticManager.selection()
                            selectedLanguage = code
                            // Применяем язык
                            UserDefaults.standard.set([code], forKey: "AppleLanguages")
                            // synchronize() не нужен в современных версиях iOS - данные сохраняются автоматически
                            dismiss()
                        } label: {
                            HStack {
                                Text(flag)
                                    .font(.system(size: 28))

                                Text(name)
                                    .font(Design.Typography.body)
                                    .foregroundStyle(Design.Colors.textPrimary)

                                Spacer()

                                if selectedLanguage == code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Design.Colors.accentPrimary)
                                }
                            }
                            .padding(.vertical, Design.Spacing.xs)
                        }
                    }

                    Section {
                        Text("Restart the app to apply language changes")
                            .font(Design.Typography.caption1)
                            .foregroundStyle(Design.Colors.textTertiary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
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
