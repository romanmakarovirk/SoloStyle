//
//  SoloStyleWidget.swift
//  SoloStyle
//
//  Home screen widgets showing live appointment data from SwiftData.
//
//  SETUP INSTRUCTIONS:
//  1. In Xcode: File → New → Target → Widget Extension (name: "SoloStyleWidget")
//  2. Uncomment the code below and move this file to the widget extension target
//  3. Add App Group "group.com.solostyle.shared" to both the app and widget targets
//  4. In the main app's SoloStyleApp.swift, use the same App Group for ModelContainer
//  5. Build and run — widgets will read live data from the shared SwiftData store
//

/*

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Data Provider

struct SoloStyleWidgetEntry: TimelineEntry {
    let date: Date
    let todayAppointmentCount: Int
    let nextAppointmentClient: String?
    let nextAppointmentService: String?
    let nextAppointmentTime: Date?
    let weekRevenue: Decimal
    let todaySchedule: [(client: String, service: String, time: Date)]
}

struct SoloStyleProvider: TimelineProvider {
    static let appGroupID = "group.com.solostyle.shared"

    func placeholder(in context: Context) -> SoloStyleWidgetEntry {
        SoloStyleWidgetEntry(
            date: Date(),
            todayAppointmentCount: 3,
            nextAppointmentClient: "Client",
            nextAppointmentService: "Service",
            nextAppointmentTime: Date().addingTimeInterval(3600),
            weekRevenue: 450,
            todaySchedule: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SoloStyleWidgetEntry) -> Void) {
        completion(fetchLiveEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SoloStyleWidgetEntry>) -> Void) {
        let entry = fetchLiveEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchLiveEntry() -> SoloStyleWidgetEntry {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        do {
            let config = ModelConfiguration(
                schema: Schema([Master.self, Service.self, Appointment.self, Client.self, WorkSchedule.self]),
                url: containerURL()
            )
            let container = try ModelContainer(for: Appointment.self, Service.self, Client.self, configurations: config)
            let context = ModelContext(container)

            // Today's appointments
            let todayPredicate = #Predicate<Appointment> { $0.date >= startOfToday && $0.date < endOfToday }
            let todayAppointments = (try? context.fetch(FetchDescriptor<Appointment>(
                predicate: todayPredicate, sortBy: [SortDescriptor(\Appointment.date)]
            ))) ?? []

            // Next scheduled
            let scheduledPredicate = #Predicate<Appointment> { $0.date > now && $0.statusRaw == "scheduled" }
            var scheduledDesc = FetchDescriptor<Appointment>(predicate: scheduledPredicate, sortBy: [SortDescriptor(\Appointment.date)])
            scheduledDesc.fetchLimit = 1
            let nextAppointment = (try? context.fetch(scheduledDesc))?.first

            // Week revenue
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            let weekPredicate = #Predicate<Appointment> { $0.date >= weekAgo && $0.date <= now && $0.statusRaw == "completed" }
            let weekAppts = (try? context.fetch(FetchDescriptor<Appointment>(predicate: weekPredicate))) ?? []
            let weekRevenue = weekAppts.compactMap { $0.service?.price }.reduce(0, +)

            let schedule = todayAppointments.map { (client: $0.client?.name ?? "Client", service: $0.service?.name ?? "Service", time: $0.date) }

            return SoloStyleWidgetEntry(
                date: now, todayAppointmentCount: todayAppointments.count,
                nextAppointmentClient: nextAppointment?.client?.name,
                nextAppointmentService: nextAppointment?.service?.name,
                nextAppointmentTime: nextAppointment?.date,
                weekRevenue: weekRevenue, todaySchedule: schedule
            )
        } catch {
            return SoloStyleWidgetEntry(date: now, todayAppointmentCount: 0, nextAppointmentClient: nil,
                nextAppointmentService: nil, nextAppointmentTime: nil, weekRevenue: 0, todaySchedule: [])
        }
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
            .appendingPathComponent("SoloStyle.store")
            ?? URL.applicationSupportDirectory.appendingPathComponent("SoloStyle.store")
    }
}

// MARK: - Widget Views (Small / Medium / Large)

struct SoloStyleSmallWidgetView: View {
    let entry: SoloStyleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(.blue)
                Text("Today").font(.caption.bold()).foregroundStyle(.secondary)
            }
            Text("\(entry.todayAppointmentCount)").font(.system(size: 36, weight: .bold, design: .rounded))
            Text("appointments").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            if let time = entry.nextAppointmentTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2)
                    Text(time, style: .time).font(.caption2.bold())
                }.foregroundStyle(.blue)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }
}

struct SoloStyleMediumWidgetView: View {
    let entry: SoloStyleWidgetEntry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Image(systemName: "calendar").foregroundStyle(.blue); Text("Today").font(.caption.bold()) }
                Text("\(entry.todayAppointmentCount)").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("appointments").font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Next").font(.caption.bold()).foregroundStyle(.secondary)
                if let client = entry.nextAppointmentClient {
                    Text(client).font(.subheadline.bold()).lineLimit(1)
                    if let svc = entry.nextAppointmentService { Text(svc).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    if let time = entry.nextAppointmentTime { Text(time, style: .time).font(.caption.bold()).foregroundStyle(.blue) }
                } else { Text("No upcoming").font(.subheadline).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding()
    }
}

struct SoloStyleLargeWidgetView: View {
    let entry: SoloStyleWidgetEntry
    private var formattedRevenue: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = Locale.current.currency?.identifier ?? "RUB"; f.maximumFractionDigits = 0
        return f.string(from: entry.weekRevenue as NSDecimalNumber) ?? "0"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Schedule").font(.headline)
                    Text("\(entry.todayAppointmentCount) appointments").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedRevenue).font(.subheadline.bold()).foregroundStyle(.green)
                    Text("this week").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Divider()
            if entry.todaySchedule.isEmpty {
                Spacer()
                Text("No appointments today").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(Array(entry.todaySchedule.prefix(5).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Text(item.time, style: .time).font(.caption.bold().monospacedDigit()).foregroundStyle(.blue).frame(width: 55, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.client).font(.caption.bold()).lineLimit(1)
                            Text(item.service).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                }
                if entry.todaySchedule.count > 5 { Text("+\(entry.todaySchedule.count - 5) more").font(.caption2).foregroundStyle(.secondary) }
            }
        }.padding()
    }
}

// MARK: - Widget Configuration

struct SoloStyleWidget: Widget {
    let kind = "SoloStyleWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoloStyleProvider()) { entry in
            SoloStyleSmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SoloStyle")
        .description("View today's appointments, next visit, and weekly revenue.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

*/
