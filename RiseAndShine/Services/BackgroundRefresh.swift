import Foundation
import BackgroundTasks

/// Asks iOS to wake the app roughly daily so the 14-day alarm horizon keeps rolling
/// forward even if the user rarely opens the app. AlarmKit alarms already scheduled
/// fire regardless; this only tops up future days.
enum BackgroundRefresh {
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: AppGroup.backgroundRefreshTask)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator or a device without background refresh; harmless.
        }
    }
}
