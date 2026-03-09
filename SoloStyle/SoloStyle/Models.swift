//
//  Models.swift
//  SoloStyle
//
//  SwiftData models with performance optimizations
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Stats Cache Manager

@MainActor
final class StatsCache {
    static let shared = StatsCache()

    private(set) var clientCount: Int = 0
    private(set) var appointmentCount: Int = 0
    private(set) var thisMonthAppointments: Int = 0
    private(set) var activeServicesCount: Int = 0
    private(set) var thisMonthEarnings: Decimal = 0
    private(set) var thisYearEarnings: Decimal = 0

    private var lastRefresh: Date = .distantPast
    private let cacheTimeout: TimeInterval = 5.0 // Refresh every 5 seconds max

    private init() {}

    func refreshIfNeeded(context: ModelContext) {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastRefresh) > cacheTimeout else { return }
        refresh(context: context)
    }

    func refresh(context: ModelContext) {
        let currentTime = Date()
        lastRefresh = currentTime
        let calendar = Calendar.current

        // Client count
        let clientDescriptor = FetchDescriptor<Client>()
        clientCount = (try? context.fetchCount(clientDescriptor)) ?? 0

        // Total appointments
        let appointmentDescriptor = FetchDescriptor<Appointment>()
        appointmentCount = (try? context.fetchCount(appointmentDescriptor)) ?? 0

        // This month appointments & earnings
        if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentTime)),
           let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
            let completedStatus = "completed"
            let predicate = #Predicate<Appointment> { appointment in
                appointment.date >= startOfMonth && appointment.date <= endOfMonth
            }
            var descriptor = FetchDescriptor<Appointment>(predicate: predicate)
            descriptor.fetchLimit = 1000
            thisMonthAppointments = (try? context.fetchCount(descriptor)) ?? 0

            // Calculate this month earnings from completed appointments
            let earningsPredicate = #Predicate<Appointment> { appointment in
                appointment.date >= startOfMonth && appointment.date <= endOfMonth && appointment.statusRaw == completedStatus
            }
            var earningsDescriptor = FetchDescriptor<Appointment>(predicate: earningsPredicate)
            earningsDescriptor.fetchLimit = 1000
            if let appointments = try? context.fetch(earningsDescriptor) {
                thisMonthEarnings = appointments.compactMap { $0.service?.price }.reduce(0, +)
            }
        }

        // This year earnings
        if let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: currentTime)),
           let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear) {
            let completedStatus = "completed"
            let yearPredicate = #Predicate<Appointment> { appointment in
                appointment.date >= startOfYear && appointment.date <= endOfYear && appointment.statusRaw == completedStatus
            }
            var yearDescriptor = FetchDescriptor<Appointment>(predicate: yearPredicate)
            yearDescriptor.fetchLimit = 5000
            if let appointments = try? context.fetch(yearDescriptor) {
                thisYearEarnings = appointments.compactMap { $0.service?.price }.reduce(0, +)
            }
        }

        // Active services
        let servicePredicate = #Predicate<Service> { $0.isActive }
        let serviceDescriptor = FetchDescriptor<Service>(predicate: servicePredicate)
        activeServicesCount = (try? context.fetchCount(serviceDescriptor)) ?? 0
    }

    func invalidate() {
        lastRefresh = .distantPast
    }
}

// MARK: - User Role

enum UserRole: String, Codable, Sendable {
    case master
    case client
}

// MARK: - Currency Formatter (cached)

enum CurrencyFormat {
    static let localized: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "RUB"
        return f
    }()
}

// MARK: - Master

@Model
final class Master {
    var id: UUID = UUID()
    var name: String = ""
    var businessName: String?
    var bio: String?
    var publicSlug: String = ""
    var email: String?
    var phone: String?
    var createdAt: Date = Date()

    // Auth & Role
    var userRole: String = "master"
    var telegramId: Int64 = 0
    var telegramUsername: String?
    var telegramFirstName: String?
    var telegramPhotoUrl: String?
    var isAuthenticated: Bool = false

    var role: UserRole {
        get { UserRole(rawValue: userRole) ?? .master }
        set { userRole = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Service.master)
    var services: [Service] = []

    @Relationship(deleteRule: .cascade, inverse: \Client.master)
    var clients: [Client] = []

    @Relationship(deleteRule: .cascade, inverse: \Appointment.master)
    var appointments: [Appointment] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkSchedule.master)
    var workSchedule: WorkSchedule?

    init(name: String, businessName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.businessName = businessName
        self.publicSlug = name.lowercased().replacingOccurrences(of: " ", with: "_") + "_\(UUID().uuidString.prefix(4))"
        self.createdAt = Date()
    }
}   

// MARK: - Service

@Model
final class Service {
    #if compiler(>=6.2)
    #Index<Service>([\.isActive], [\.name])
    #endif

    var id: UUID = UUID()
    var name: String = ""
    var price: Decimal = 0
    var duration: Int = 30
    var isActive: Bool = true
    var createdAt: Date = Date()

    var master: Master?

    @Relationship(deleteRule: .nullify, inverse: \Appointment.service)
    var appointments: [Appointment] = []

    var formattedPrice: String {
        CurrencyFormat.localized.string(from: price as NSDecimalNumber) ?? "\(price)"
    }

    var formattedDuration: String {
        if duration >= 60 {
            return "\(duration / 60)h \(duration % 60)m"
        }
        return "\(duration) min"
    }

    init(name: String, price: Decimal, duration: Int) {
        self.id = UUID()
        self.name = name
        self.price = price
        self.duration = duration
        self.createdAt = Date()
    }
}

// MARK: - Client Loyalty Tier

enum LoyaltyTier: String, Codable {
    case newbie = "Newbie"
    case regular = "Regular"
    case vip = "VIP"
    case elite = "Elite"

    var icon: String {
        switch self {
        case .newbie: return "star"
        case .regular: return "star.fill"
        case .vip: return "crown"
        case .elite: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .newbie: return .gray
        case .regular: return .blue
        case .vip: return .orange
        case .elite: return .purple
        }
    }

    var minVisits: Int {
        switch self {
        case .newbie: return 0
        case .regular: return 3
        case .vip: return 10
        case .elite: return 25
        }
    }
}

// MARK: - Client

@Model
final class Client {
    #if compiler(>=6.2)
    #Index<Client>([\.name], [\.createdAt])
    #endif

    var id: UUID = UUID()
    var name: String = ""
    var phone: String?
    var email: String?
    var notes: String?
    var createdAt: Date = Date()
    var totalSpent: Decimal = 0

    var master: Master?

    @Relationship(deleteRule: .nullify, inverse: \Appointment.client)
    var appointments: [Appointment] = []

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var completedVisits: Int {
        appointments.filter { $0.status == .completed }.count
    }

    var loyaltyTier: LoyaltyTier {
        let visits = completedVisits
        if visits >= LoyaltyTier.elite.minVisits { return .elite }
        if visits >= LoyaltyTier.vip.minVisits { return .vip }
        if visits >= LoyaltyTier.regular.minVisits { return .regular }
        return .newbie
    }

    var visitsToNextTier: Int? {
        switch loyaltyTier {
        case .newbie: return LoyaltyTier.regular.minVisits - completedVisits
        case .regular: return LoyaltyTier.vip.minVisits - completedVisits
        case .vip: return LoyaltyTier.elite.minVisits - completedVisits
        case .elite: return nil
        }
    }

    var lastVisitDate: Date? {
        appointments
            .filter { $0.status == .completed }
            .max(by: { $0.date < $1.date })?
            .date
    }

    var formattedTotalSpent: String {
        CurrencyFormat.localized.string(from: totalSpent as NSDecimalNumber) ?? "\(totalSpent)"
    }

    init(name: String, phone: String? = nil, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.email = email
        self.createdAt = Date()
    }
}

// MARK: - Appointment

enum AppointmentStatus: String, Codable {
    case scheduled, completed, cancelled, noShow

    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .noShow: return .orange
        }
    }
}

@Model
final class Appointment {
    #if compiler(>=6.2)
    #Index<Appointment>([\.date], [\.statusRaw])
    #endif

    var id: UUID = UUID()
    var date: Date = Date()
    var statusRaw: String = "scheduled"
    var notes: String?
    var reminderSent: Bool = false
    var createdAt: Date = Date()

    // Gallery photos (stored as file names)
    var beforePhotoPath: String?
    var afterPhotoPath: String?

    var master: Master?
    var client: Client?

    var service: Service?

    var status: AppointmentStatus {
        get { AppointmentStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    var formattedTime: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var hasPhotos: Bool {
        beforePhotoPath != nil || afterPhotoPath != nil
    }

    init(date: Date, service: Service?, client: Client?) {
        self.id = UUID()
        self.date = date
        self.service = service
        self.client = client
        self.createdAt = Date()
    }
}

// MARK: - WorkSchedule

@Model
final class WorkSchedule {
    var id: UUID = UUID()
    var mondayStart: Int = 9
    var mondayEnd: Int = 18
    var tuesdayStart: Int = 9
    var tuesdayEnd: Int = 18
    var wednesdayStart: Int = 9
    var wednesdayEnd: Int = 18
    var thursdayStart: Int = 9
    var thursdayEnd: Int = 18
    var fridayStart: Int = 9
    var fridayEnd: Int = 18
    var saturdayStart: Int = 10
    var saturdayEnd: Int = 16
    var sundayOff: Bool = true

    var master: Master?

    init() {
        self.id = UUID()
    }
}
