//
//  LiveActivityManager.swift
//  SoloStyle
//
//  Dynamic Island & Live Activities for active appointments
//  Manager lives in the main app target; widget UI should be in Widget Extension.
//  Requires "Supports Live Activities = YES" in Info.plist
//

import Foundation
import ActivityKit
import SwiftUI

// MARK: - Activity Attributes (shared between app and widget extension)

struct SoloStyleActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var minutesRemaining: Int
        var progress: Double
    }

    var clientName: String
    var serviceName: String
    var startTime: Date
    var endTime: Date
}

// MARK: - Live Activity Manager

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private(set) var isActivityActive = false

    private var currentActivity: Activity<SoloStyleActivityAttributes>?
    private var updateTimer: Timer?

    private init() {}

    /// Start a live activity for the current appointment session
    func startActivity(clientName: String, serviceName: String, durationMinutes: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing activity first
        if isActivityActive {
            endActivity()
        }

        let now = Date()
        guard let endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: now) else { return }

        let attributes = SoloStyleActivityAttributes(
            clientName: clientName,
            serviceName: serviceName,
            startTime: now,
            endTime: endTime
        )

        let initialState = SoloStyleActivityAttributes.ContentState(
            status: "In Progress",
            minutesRemaining: durationMinutes,
            progress: 0.0
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: endTime)
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isActivityActive = true
            startUpdateTimer(endTime: endTime, totalMinutes: durationMinutes)
        } catch {
            isActivityActive = false
        }
    }

    /// Update the live activity countdown
    func updateActivity(minutesRemaining: Int, progress: Double) {
        guard let activity = currentActivity else { return }

        let state = SoloStyleActivityAttributes.ContentState(
            status: minutesRemaining > 0 ? "In Progress" : "Finishing",
            minutesRemaining: max(0, minutesRemaining),
            progress: min(1.0, progress)
        )

        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    /// End the live activity (appointment completed)
    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = SoloStyleActivityAttributes.ContentState(
            status: "Completed",
            minutesRemaining: 0,
            progress: 1.0
        )

        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .after(.now + 60))
        }

        cleanUp()
    }

    /// Cancel the live activity immediately
    func cancelActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        cleanUp()
    }

    // MARK: - Private

    private func cleanUp() {
        updateTimer?.invalidate()
        updateTimer = nil
        currentActivity = nil
        isActivityActive = false
    }

    private func startUpdateTimer(endTime: Date, totalMinutes: Int) {
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleTimerTick(endTime: endTime, totalMinutes: totalMinutes)
            }
        }
    }

    private func handleTimerTick(endTime: Date, totalMinutes: Int) {
        let now = Date()
        let remaining = Int(endTime.timeIntervalSince(now) / 60)
        let elapsed = totalMinutes - remaining
        let progress = Double(elapsed) / Double(max(1, totalMinutes))

        if remaining <= 0 {
            endActivity()
        } else {
            updateActivity(minutesRemaining: remaining, progress: progress)
        }
    }
}
