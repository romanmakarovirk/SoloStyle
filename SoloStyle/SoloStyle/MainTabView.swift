//
//  MainTabView.swift
//  SoloStyle
//
//  Main navigation with Liquid Glass tab bar
//

import SwiftUI

struct MainTabView: View {
    @Binding var quickActionDestination: QuickActionDestination?

    @State private var selectedTab: Tab = .calendar
    @State private var showingNewAppointment = false
    @State private var showingNewClient = false
    @State private var showingAnalytics = false

    init(quickActionDestination: Binding<QuickActionDestination?> = .constant(nil)) {
        self._quickActionDestination = quickActionDestination
    }

    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content — all tabs stay alive so onAppear animations fire only once
            ZStack {
                CalendarView()
                    .opacity(selectedTab == .calendar ? 1 : 0)
                    .allowsHitTesting(selectedTab == .calendar)

                ClientsView()
                    .opacity(selectedTab == .clients ? 1 : 0)
                    .allowsHitTesting(selectedTab == .clients)

                AIAssistantView(tabBarHeight: tabBarHeight)
                    .opacity(selectedTab == .ai ? 1 : 0)
                    .allowsHitTesting(selectedTab == .ai)

                ProfileView()
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Tab Bar
            GlassTabBar(selectedTab: $selectedTab)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TabBarHeightKey.self, value: geo.size.height)
                    }
                )
        }
        .onPreferenceChange(TabBarHeightKey.self) { tabBarHeight = $0 }
        .background(Design.Colors.backgroundPrimary)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showingNewAppointment) {
            AddAppointmentView(selectedDate: Date())
        }
        .sheet(isPresented: $showingNewClient) {
            AddClientView()
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
            guard let destination = notification.object as? QuickActionDestination else { return }
            handleQuickAction(destination)
        }
        .onChange(of: quickActionDestination) { _, newValue in
            if let destination = newValue {
                handleQuickAction(destination)
                quickActionDestination = nil
            }
        }
    }

    private func handleQuickAction(_ destination: QuickActionDestination) {
        HapticManager.impact(.medium)

        switch destination {
        case .newAppointment:
            selectedTab = .calendar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingNewAppointment = true
            }
        case .newClient:
            selectedTab = .clients
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingNewClient = true
            }
        case .todaySchedule:
            selectedTab = .calendar
        case .analytics:
            showingAnalytics = true
        }
    }
}

// MARK: - Tab Bar Height Preference Key

private struct TabBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    MainTabView()
}
