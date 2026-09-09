import Foundation
import AlarmKit

/// Extra data carried on each system alarm so the Live Activity can render it.
/// Must be `nonisolated` because AlarmKit encodes it off the main actor.
nonisolated struct SunriseAlarmMetadata: AlarmMetadata {
    /// "yyyy-MM-dd" of the morning the alarm is for.
    let dateKey: String
    /// The sunrise instant the alarm is relative to.
    let sunrise: Date
    /// Human description like "30 min before sunrise".
    let offsetDescription: String
    let locationName: String

    init(dateKey: String, sunrise: Date, offsetDescription: String, locationName: String) {
        self.dateKey = dateKey
        self.sunrise = sunrise
        self.offsetDescription = offsetDescription
        self.locationName = locationName
    }
}
