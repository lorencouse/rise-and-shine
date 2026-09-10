import Foundation
import AlarmKit

/// Extra data carried on each system alarm so the Live Activity can render it.
/// Must be `nonisolated` because AlarmKit encodes it off the main actor.
nonisolated struct SunriseAlarmMetadata: AlarmMetadata {
    /// "yyyy-MM-dd" of the morning the alarm is for.
    let dateKey: String
    /// The sunrise instant the alarm is relative to. `nil` in polar night, when the clamp
    /// still produces an alarm but there is no sunrise to point at.
    let sunrise: Date?
    /// Human description like "30 min before sunrise".
    let offsetDescription: String
    let locationName: String
    /// When the alarm actually rings. A countdown ending here is the pre-alarm; one ending
    /// later is a snooze.
    let alarmTime: Date?

    init(dateKey: String, sunrise: Date?, offsetDescription: String, locationName: String, alarmTime: Date? = nil) {
        self.dateKey = dateKey
        self.sunrise = sunrise
        self.offsetDescription = offsetDescription
        self.locationName = locationName
        self.alarmTime = alarmTime
    }
}
