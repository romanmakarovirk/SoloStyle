//
//  SoloStyleApp.swift
//  SoloStyle
//
//  Main app entry point
//

import SwiftUI
import SwiftData

@main
struct SoloStyleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Master.self,
            Service.self,
            Appointment.self,
            Client.self,
            WorkSchedule.self
        ])

        // One-time migration: clear store after schema change (v3 — added Telegram auth fields)
        let migrationKey = "db_schema_v3"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupport = urls.first {
                for ext in ["store", "store-shm", "store-wal"] {
                    let file = appSupport.appendingPathComponent("default.\(ext)")
                    try? FileManager.default.removeItem(at: file)
                }
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Database error: \(error). Falling back to in-memory storage.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Critical database error: \(error)")
            }
        }
    }()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var quickActionDestination: QuickActionDestination?
    @State private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !authManager.isAuthenticated {
                    // Not logged in — show Telegram login
                    OnboardingView()
                } else if authManager.selectedRole == nil {
                    // Logged in but no role selected
                    RoleSelectionView()
                } else if authManager.selectedRole == .client {
                    // Client role — simplified UI
                    ClientMainView()
                } else {
                    // Master role — full UI
                    if hasCompletedOnboarding {
                        MainTabView(quickActionDestination: $quickActionDestination)
                    } else {
                        OnboardingView()
                    }
                }
            }
            .onOpenURL { url in
                Task {
                    await authManager.handleAuthCallback(url: url)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Quick Actions

enum QuickActionDestination: String {
    case newAppointment = "newAppointment"
    case newClient = "newClient"
    case todaySchedule = "todaySchedule"
    case analytics = "analytics"
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        setupQuickActions(for: application)
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    private func setupQuickActions(for application: UIApplication) {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: QuickActionDestination.newAppointment.rawValue,
                localizedTitle: L.shortcutNewAppointment,
                localizedSubtitle: L.shortcutNewAppointmentSub,
                icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.plus")
            ),
            UIApplicationShortcutItem(
                type: QuickActionDestination.newClient.rawValue,
                localizedTitle: L.shortcutAddClient,
                localizedSubtitle: L.shortcutAddClientSub,
                icon: UIApplicationShortcutIcon(systemImageName: "person.badge.plus")
            ),
            UIApplicationShortcutItem(
                type: QuickActionDestination.todaySchedule.rawValue,
                localizedTitle: L.shortcutTodaySchedule,
                localizedSubtitle: L.shortcutTodayScheduleSub,
                icon: UIApplicationShortcutIcon(systemImageName: "calendar")
            ),
            UIApplicationShortcutItem(
                type: QuickActionDestination.analytics.rawValue,
                localizedTitle: L.shortcutAnalytics,
                localizedSubtitle: L.shortcutAnalyticsSub,
                icon: UIApplicationShortcutIcon(systemImageName: "chart.bar")
            )
        ]
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleQuickAction(shortcutItem)
        completionHandler(true)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            handleQuickAction(shortcutItem)
        }
    }

    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        guard let destination = QuickActionDestination(rawValue: shortcutItem.type) else { return }
        NotificationCenter.default.post(name: .quickActionTriggered, object: destination)
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}
