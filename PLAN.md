# 📋 SoloStyle — Implementation Plan

## Executive Summary

**SoloStyle** — нативное iOS приложение для мастеров и фрилансеров. Управление записями, минимизация неявок, приём платежей.

**Tech Stack:**
- Swift 6.0 + SwiftUI
- iOS 26+ (Liquid Glass design)
- SwiftData + CloudKit
- EventKit, Messages Framework
- StoreKit 2 + Stripe SDK

**Timeline:** 6 фаз разработки

---

## Phase 1: Foundation (Текущая фаза)

### 1.1 Project Setup
```
Tasks:
├── Create Xcode project (iOS 26+)
├── Configure bundle ID: com.solostyle.app
├── Set up git repository
├── Configure development team
└── Create folder structure
```

### 1.2 Design System
```
Tasks:
├── Create DesignSystem.swift (tokens)
├── Implement GlassCard component
├── Implement GlassButton component
├── Implement GlassTabBar component
├── Create Typography styles
├── Define Color palette
└── Create spacing/radius constants
```

### 1.3 Core Models (SwiftData)
```swift
// Master.swift
@Model class Master {
    var id: UUID
    var name: String
    var businessName: String?
    var profileImageData: Data?
    var publicSlug: String          // "master_name" for URL
    var createdAt: Date

    @Relationship var services: [Service]
    @Relationship var workSchedule: WorkSchedule?
    @Relationship var appointments: [Appointment]
    @Relationship var clients: [Client]
}

// Service.swift
@Model class Service {
    var id: UUID
    var name: String
    var price: Decimal
    var duration: Int               // minutes
    var isActive: Bool

    @Relationship(inverse: \Master.services) var master: Master?
}

// Appointment.swift
@Model class Appointment {
    var id: UUID
    var date: Date
    var status: AppointmentStatus   // scheduled, completed, cancelled, noShow
    var notes: String?
    var reminderSent: Bool
    var eventKitID: String?         // Calendar event ID

    @Relationship var service: Service?
    @Relationship var client: Client?
    @Relationship(inverse: \Master.appointments) var master: Master?
}

// Client.swift
@Model class Client {
    var id: UUID
    var name: String
    var phone: String?
    var email: String?
    var notes: String?
    var createdAt: Date

    @Relationship(inverse: \Master.clients) var master: Master?
    @Relationship var appointments: [Appointment]
}

// WorkSchedule.swift
@Model class WorkSchedule {
    var id: UUID
    var monday: DaySchedule?
    var tuesday: DaySchedule?
    var wednesday: DaySchedule?
    var thursday: DaySchedule?
    var friday: DaySchedule?
    var saturday: DaySchedule?
    var sunday: DaySchedule?
    var breakDuration: Int          // minutes

    @Relationship(inverse: \Master.workSchedule) var master: Master?
}

struct DaySchedule: Codable {
    var isWorkingDay: Bool
    var startTime: Date
    var endTime: Date
    var breakStart: Date?
    var breakEnd: Date?
}
```

### 1.4 Navigation Structure
```
MainTabView
├── Tab 1: Calendar (CalendarView)
├── Tab 2: Clients (ClientsListView)
├── Tab 3: Profile (ProfileView)
└── Tab 4: Settings (SettingsView)
```

---

## Phase 2: Profile & Services

### 2.1 Onboarding Flow
```
Screens:
├── Welcome screen
├── Name & business name input
├── Profile photo (optional)
├── Services setup
├── Work schedule setup
└── Completion + public link reveal
```

### 2.2 Profile Management
```
Features:
├── Edit profile info
├── Change profile photo
├── View/copy public booking link
└── QR code generation for link
```

### 2.3 Services Management
```
Features:
├── List all services
├── Add new service (name, price, duration)
├── Edit existing service
├── Delete/deactivate service
└── Reorder services
```

### 2.4 Work Schedule
```
Features:
├── Set working days
├── Set start/end time per day
├── Set break time
├── Mark vacation days
└── Copy schedule to other days
```

---

## Phase 3: Calendar & Appointments

### 3.1 Calendar Views
```
Views:
├── DayView — hourly slots
├── WeekView — 7 day overview
├── MonthView — month grid
└── AgendaView — list of upcoming
```

### 3.2 Appointment Management
```
Features:
├── Quick add appointment
├── Select client (existing/new)
├── Select service
├── Choose time slot
├── Add notes
├── Edit appointment
├── Cancel appointment
├── Mark as completed/no-show
```

### 3.3 EventKit Integration
```
Features:
├── Request calendar access
├── Create calendar event on booking
├── Update event on changes
├── Delete event on cancellation
├── Sync existing appointments
```

### 3.4 Time Slot Logic
```
Algorithm:
├── Get working hours for date
├── Get all appointments for date
├── Calculate available slots based on service duration
├── Account for breaks
└── Return available time slots
```

---

## Phase 4: Clients & Notifications

### 4.1 Client Management
```
Features:
├── List all clients
├── Search/filter clients
├── Add new client
├── Edit client details
├── View client history
├── Delete client (with confirmation)
```

### 4.2 iMessage Reminders
```
Implementation:
├── MFMessageComposeViewController
├── Schedule reminder 24h before
├── Message template with appointment details
├── Handle delivery status
└── Fallback: Open Messages app
```

### 4.3 Local Notifications
```
Features:
├── Request notification permission
├── Remind master about upcoming appointments
├── Daily summary notification
└── No-show follow-up reminder
```

---

## Phase 5: Payments & Subscription

### 5.1 StoreKit 2 Integration
```
Products:
├── com.solostyle.pro.monthly — $9.99/month
└── com.solostyle.pro.yearly — $79.99/year (optional)

Features:
├── Purchase flow
├── Restore purchases
├── Subscription status check
├── Grace period handling
└── Receipt validation
```

### 5.2 Freemium Logic
```
Free Tier Limits:
├── Max 5 active clients
├── Basic calendar views
├── Manual reminders only

Pro Features:
├── Unlimited clients
├── Auto reminders
├── Advanced analytics (future)
├── Priority support
```

### 5.3 Stripe Integration (Phase 5.5)
```
Features:
├── Deposit collection
├── Payment links
├── Refund handling
└── Payout to master account
```

---

## Phase 6: Polish & Launch

### 6.1 Localization
```
Languages:
├── en — English (primary)
└── es-MX — Spanish (Mexico)

Files:
├── Localizable.xcstrings
├── InfoPlist.xcstrings
└── Localized assets
```

### 6.2 Onboarding Refinement
```
Features:
├── Animated illustrations
├── Skip option
├── Progress indicator
└── Login for existing users
```

### 6.3 Backend Deployment
```
Server (77.110.115.239):
├── Set up Node.js/FastAPI
├── PostgreSQL database
├── API endpoints:
│   ├── GET /booking/:slug — public booking page
│   ├── POST /booking/:slug/appointments — create booking
│   ├── POST /webhooks/stripe — payment webhooks
│   └── POST /notifications/send — push notifications
├── Nginx configuration
└── SSL certificate (Let's Encrypt)
```

### 6.4 App Store Preparation
```
Assets:
├── App icon (1024x1024)
├── Screenshots (6.7", 6.5", 5.5")
├── App preview video (optional)
├── Description (EN, ES-MX)
├── Keywords
├── Privacy policy URL
└── Support URL
```

---

## Technical Implementation Details

### Liquid Glass Components

```swift
// GlassCard.swift
struct GlassCard<Content: View>: View {
    let content: Content
    var tint: Color = .white.opacity(0.1)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .glassEffect(.regular.tint(tint))
    }
}

// GlassButton.swift
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .glassEffect(.regular.interactive())
    }
}

// GlassTabBar.swift
struct GlassTabBar: View {
    @Binding var selectedTab: Tab
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(Tab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: namespace
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .glassEffect()
    }
}
```

### Public Booking Flow

```
1. User visits: solostyle.app/book/master_name
2. Server fetches master profile from CloudKit/DB
3. Shows available services and time slots
4. Client selects service + time + enters details
5. Booking created → Master notified → Calendar updated
6. Client receives confirmation (email/SMS)
```

### Data Sync Architecture

```
┌─────────────────┐
│   iPhone App    │
│   (SwiftData)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    CloudKit     │
│  (Private DB)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Backend Server │
│ (Public Booking)│
└─────────────────┘
```

---

## File Ownership

| Module | Primary Owner | Secondary |
|--------|--------------|-----------|
| Design System | Claude | Cursor |
| Models | Claude | Cursor |
| Calendar | Cursor | Claude |
| Clients | Cursor | Claude |
| Profile | Claude | Cursor |
| Settings | Claude | Cursor |
| Payments | Claude | - |
| Backend | TBD | TBD |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| CloudKit complexity | High | Start with local-only, add sync later |
| iMessage limitations | Medium | Clear user messaging about Apple-only |
| StoreKit rejection | High | Follow guidelines strictly |
| Server security | High | Proper auth, rate limiting, SSL |

---

## Success Metrics (MVP)

- [ ] App launches without crash
- [ ] Can create profile and services
- [ ] Can add/edit/delete appointments
- [ ] Calendar syncs with iOS Calendar
- [ ] iMessage reminders work
- [ ] Subscription purchase works
- [ ] Public booking link works

---

*Plan created: 2025-12-13*
*Last updated: 2025-12-13*
