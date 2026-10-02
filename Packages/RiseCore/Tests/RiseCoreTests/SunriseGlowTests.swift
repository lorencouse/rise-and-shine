import Testing
import Foundation
@testable import RiseCore

struct SunriseGlowTests {
    /// 07:00 on an arbitrary morning.
    private let alarm = Date(timeIntervalSince1970: 1_788_030_000)

    private func at(_ minutesFromAlarm: Double) -> Date {
        alarm.addingTimeInterval(minutesFromAlarm * 60)
    }

    @Test func offWhenDurationIsZero() {
        #expect(SunriseGlow.start(alarm: alarm, durationMinutes: 0) == nil)
        #expect(SunriseGlow.progress(now: at(-1), alarm: alarm, durationMinutes: 0) == nil)
        #expect(SunriseGlow.stage(now: at(-1), alarm: alarm, durationMinutes: 0, maxBrightness: 1) == nil)
    }

    @Test func nothingBeforeTheRampStarts() {
        #expect(SunriseGlow.progress(now: at(-31), alarm: alarm, durationMinutes: 30) == nil)
        #expect(SunriseGlow.progress(now: at(-30), alarm: alarm, durationMinutes: 30) == 0)
    }

    @Test func progressIsLinearAcrossTheRamp() {
        #expect(SunriseGlow.progress(now: at(-15), alarm: alarm, durationMinutes: 30) == 0.5)
        #expect(SunriseGlow.progress(now: at(-7.5), alarm: alarm, durationMinutes: 30) == 0.75)
        #expect(SunriseGlow.progress(now: alarm, alarm: alarm, durationMinutes: 30) == 1)
    }

    /// The light has to stay on while you are stopping the alarm and getting up, then
    /// give the screen back.
    @Test func holdsAtFullAfterTheAlarmThenEnds() {
        #expect(SunriseGlow.progress(now: at(15), alarm: alarm, durationMinutes: 30) == 1)
        #expect(SunriseGlow.stage(now: at(15), alarm: alarm, durationMinutes: 30, maxBrightness: 1)?.isHolding == true)
        #expect(SunriseGlow.progress(now: at(31), alarm: alarm, durationMinutes: 30) == nil)
    }

    /// The whole point of the feature: start almost dark, end at the chosen ceiling, and
    /// spend most of the ramp well below halfway so it does not read as "lights on".
    @Test func brightnessRisesFromNearDarkToTheCeiling() {
        func brightness(_ m: Double, max: Double = 0.8) -> Double {
            SunriseGlow.stage(now: at(m), alarm: alarm, durationMinutes: 30, maxBrightness: max)!.brightness
        }
        #expect(brightness(-30) == SunriseGlow.minBrightness)
        #expect(abs(brightness(0) - 0.8) < 0.0001)
        #expect(brightness(-15) < 0.25)                       // halfway is still dim
        #expect(brightness(-20) < brightness(-10))
        #expect(brightness(-10) < brightness(-5))
    }

    /// A ceiling below the floor would otherwise invert the ramp.
    @Test func brightnessCeilingIsClamped() {
        let low = SunriseGlow.stage(now: alarm, alarm: alarm, durationMinutes: 30, maxBrightness: 0)!
        #expect(low.brightness == SunriseGlow.minBrightness)
        let high = SunriseGlow.stage(now: alarm, alarm: alarm, durationMinutes: 30, maxBrightness: 4)!
        #expect(high.brightness == 1)
    }

    @Test func colourWarmsMonotonically() {
        func horizon(_ m: Double) -> GlowColor {
            SunriseGlow.stage(now: at(m), alarm: alarm, durationMinutes: 30, maxBrightness: 1)!.horizon
        }
        let dark = horizon(-30), mid = horizon(-12), full = horizon(0)
        #expect(dark.red < mid.red)
        #expect(mid.red < full.red)
        #expect(mid.green < full.green)
        #expect(full.red > 0.9 && full.green > 0.8)           // ends warm white, not orange
    }

    /// Stops are interpolated, so an instant between two of them must land between them
    /// rather than snapping to one.
    @Test func colourInterpolatesBetweenStops() {
        let c = SunriseGlow.stage(now: at(-15), alarm: alarm, durationMinutes: 30, maxBrightness: 1)!.horizon
        #expect(c.red > 0.45 && c.red < 0.88)
    }

    @Test func startIsTheRampLengthBeforeTheAlarm() {
        #expect(SunriseGlow.start(alarm: alarm, durationMinutes: 20) == at(-20))
    }
}
