import Foundation
import HealthKit
import RiseCore

/// Read-only Health access for sleep analysis. The app never writes to Health: its
/// bedtimes are a plan, not a measurement, and the Watch already records the real thing.
@Observable
final class HealthService {

    enum Authorization: Equatable { case unavailable, notDetermined, authorized, denied }

    private(set) var authorization: Authorization = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    init() { refreshAuthorization() }

    /// Health hides read-permission state from apps by design, so "authorized" here means
    /// "we have asked"; a user who said no simply yields no samples.
    func refreshAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { authorization = .unavailable; return }
        authorization = UserDefaults.standard.bool(forKey: "healthAsked") ? .authorized : .notDetermined
    }

    @discardableResult
    func requestAuthorization() async -> Authorization {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
            UserDefaults.standard.set(true, forKey: "healthAsked")
        } catch {
            // Treat a failure as "asked"; the next query will just come back empty.
            UserDefaults.standard.set(true, forKey: "healthAsked")
        }
        refreshAuthorization()
        return authorization
    }

    /// Minutes asleep between two instants, summing every "asleep" stage and ignoring
    /// "in bed" and "awake". Overlapping samples from two sources are merged so a Watch
    /// and a third-party app don't double-count.
    func asleepMinutes(from start: Date, to end: Date) async -> Int? {
        guard authorization == .authorized else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let samples: [HKCategorySample]
        do {
            samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                          sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, results, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: (results as? [HKCategorySample]) ?? []) }
                }
                store.execute(query)
            }
        } catch {
            return nil
        }
        let intervals = samples.filter { asleep.contains($0.value) }
            .map { (max($0.startDate, start), min($0.endDate, end)) }
            .filter { $0.1 > $0.0 }
        guard !intervals.isEmpty else { return nil }
        // Merge overlaps.
        var total: TimeInterval = 0
        var current = intervals[0]
        for next in intervals.dropFirst() {
            if next.0 <= current.1 { current.1 = max(current.1, next.1) }
            else { total += current.1.timeIntervalSince(current.0); current = next }
        }
        total += current.1.timeIntervalSince(current.0)
        return Int(total / 60)
    }

    /// Sleep for the night that ended with `wake`: look back from the wake time far enough
    /// to catch an early bedtime, but not into the previous night.
    func sleepForNight(endingAt wake: Date) async -> Int? {
        await asleepMinutes(from: wake.addingTimeInterval(-14 * 3600), to: wake.addingTimeInterval(30 * 60))
    }
}
