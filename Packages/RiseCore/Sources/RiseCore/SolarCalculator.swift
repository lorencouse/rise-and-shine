import Foundation

/// The sun events for one civil day at one location.
///
/// All values are absolute instants. Any of them can be `nil` on days when the sun never
/// crosses the corresponding altitude (polar day / polar night).
public struct SolarDay: Sendable, Equatable, Codable {
    public let date: DateKey
    public let astronomicalDawn: Date?
    public let nauticalDawn: Date?
    public let civilDawn: Date?
    public let sunrise: Date?
    public let solarNoon: Date
    public let sunset: Date?
    public let civilDusk: Date?
    public let nauticalDusk: Date?
    public let astronomicalDusk: Date?

    public var dayLength: TimeInterval? {
        guard let sunrise, let sunset else { return nil }
        return sunset.timeIntervalSince(sunrise)
    }

    /// Returns the instant for a given anchor, if the sun reaches it on this day.
    public func time(for anchor: SunAnchor) -> Date? {
        switch anchor {
        case .sunrise: sunrise
        case .civilDawn: civilDawn
        case .firstLight: astronomicalDawn
        }
    }
}

/// Which moment of the morning the alarm is offset from.
public enum SunAnchor: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Upper limb of the sun crosses the horizon (−0.833°).
    case sunrise
    /// Civil dawn: sun at −6°. Bright enough to see outdoors.
    case civilDawn
    /// Astronomical dawn: sun at −18°. The very first hint of light.
    case firstLight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sunrise: "Sunrise"
        case .civilDawn: "Dawn"
        case .firstLight: "First light"
        }
    }

    public var detail: String {
        switch self {
        case .sunrise: "When the sun breaks the horizon."
        case .civilDawn: "About 25–35 minutes before sunrise, when it's light enough to see."
        case .firstLight: "The first trace of light, roughly 90 minutes before sunrise."
        }
    }
}

/// Pure-Foundation implementation of the NOAA solar position algorithm.
///
/// Accuracy is within about one minute of the NOAA reference calculator for latitudes
/// below ~72°, which is more than enough for an alarm clock. No network, no API key.
public enum SolarCalculator {

    /// Standard zenith angles (in degrees below the horizon) for each event.
    private enum Altitude {
        static let horizon = -0.833      // refraction + solar radius
        static let civil = -6.0
        static let nautical = -12.0
        static let astronomical = -18.0
    }

    /// Computes the sun events for the civil day containing `date` in `timeZone`.
    public static func solarDay(
        for date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current
    ) -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let key = DateKey(date: date, calendar: calendar)
        return solarDay(for: key, latitude: latitude, longitude: longitude, timeZone: timeZone)
    }

    /// Computes the sun events for a specific civil day.
    public static func solarDay(
        for key: DateKey,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current
    ) -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let localMidnight = key.startOfDay(in: calendar)

        // Julian day at local midnight, then refine each event's own time of day so the
        // equation of time and declination are evaluated near the event (NOAA method).
        let jdMidnight = julianDay(localMidnight)

        // Solar noon is needed as the seed for morning/evening events.
        let tzOffsetMinutes = Double(timeZone.secondsFromGMT(for: localMidnight)) / 60.0
        let noonMinutes = solarNoonMinutes(jdMidnight: jdMidnight, longitude: longitude, tzOffsetMinutes: tzOffsetMinutes)
        let noon = localMidnight.addingTimeInterval(noonMinutes * 60)

        func event(_ altitude: Double, rising: Bool) -> Date? {
            guard let minutes = eventMinutes(jdMidnight: jdMidnight,
                                             latitude: latitude,
                                             longitude: longitude,
                                             tzOffsetMinutes: tzOffsetMinutes,
                                             altitude: altitude,
                                             rising: rising,
                                             seedMinutes: noonMinutes) else { return nil }
            return localMidnight.addingTimeInterval(minutes * 60)
        }

        return SolarDay(
            date: key,
            astronomicalDawn: event(Altitude.astronomical, rising: true),
            nauticalDawn: event(Altitude.nautical, rising: true),
            civilDawn: event(Altitude.civil, rising: true),
            sunrise: event(Altitude.horizon, rising: true),
            solarNoon: noon,
            sunset: event(Altitude.horizon, rising: false),
            civilDusk: event(Altitude.civil, rising: false),
            nauticalDusk: event(Altitude.nautical, rising: false),
            astronomicalDusk: event(Altitude.astronomical, rising: false)
        )
    }

    /// Convenience: a run of consecutive days starting at `start`.
    public static func solarDays(
        from start: Date,
        count: Int,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current
    ) -> [SolarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let first = DateKey(date: start, calendar: calendar)
        return (0..<max(count, 0)).map { offset in
            solarDay(for: first.adding(days: offset, in: calendar),
                     latitude: latitude, longitude: longitude, timeZone: timeZone)
        }
    }

    // MARK: - NOAA core

    private static func julianDay(_ date: Date) -> Double {
        // Unix epoch is JD 2440587.5
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    private static func julianCentury(_ jd: Double) -> Double {
        (jd - 2451545.0) / 36525.0
    }

    private static func degToRad(_ d: Double) -> Double { d * .pi / 180 }
    private static func radToDeg(_ r: Double) -> Double { r * 180 / .pi }

    /// Sun's declination (degrees) and equation of time (minutes) for a Julian century.
    private static func declinationAndEquationOfTime(_ t: Double) -> (declination: Double, eqTime: Double) {
        let geomMeanLongSun = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let geomMeanAnomSun = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentEarthOrbit = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let m = degToRad(geomMeanAnomSun)
        let sunEqOfCtr = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289

        let sunTrueLong = geomMeanLongSun + sunEqOfCtr
        let sunAppLong = sunTrueLong - 0.00569 - 0.00478 * sin(degToRad(125.04 - 1934.136 * t))

        let meanObliqEcliptic = 23 + (26 + ((21.448 - t * (46.815 + t * (0.00059 - t * 0.001813)))) / 60) / 60
        let obliqCorr = meanObliqEcliptic + 0.00256 * cos(degToRad(125.04 - 1934.136 * t))

        let declination = radToDeg(asin(sin(degToRad(obliqCorr)) * sin(degToRad(sunAppLong))))

        var y = tan(degToRad(obliqCorr / 2))
        y *= y
        let l0 = degToRad(geomMeanLongSun)
        let e = eccentEarthOrbit
        let eqTime = 4 * radToDeg(
            y * sin(2 * l0)
            - 2 * e * sin(m)
            + 4 * e * y * sin(m) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0)
            - 1.25 * e * e * sin(2 * m)
        )
        return (declination, eqTime)
    }

    /// Minutes after local midnight of solar noon.
    private static func solarNoonMinutes(jdMidnight: Double, longitude: Double, tzOffsetMinutes: Double) -> Double {
        // First pass at approximate noon, then refine once.
        var t = julianCentury(jdMidnight - longitude / 360)
        var eq = declinationAndEquationOfTime(t).eqTime
        var noon = 720 - 4 * longitude - eq + tzOffsetMinutes
        t = julianCentury(jdMidnight + noon / 1440)
        eq = declinationAndEquationOfTime(t).eqTime
        noon = 720 - 4 * longitude - eq + tzOffsetMinutes
        return noon
    }

    /// Hour angle (degrees) at which the sun's centre is at `altitude`. `nil` if never reached.
    private static func hourAngle(latitude: Double, declination: Double, altitude: Double) -> Double? {
        let latR = degToRad(latitude)
        let decR = degToRad(declination)
        let zenithR = degToRad(90 - altitude)
        let cosH = cos(zenithR) / (cos(latR) * cos(decR)) - tan(latR) * tan(decR)
        guard cosH >= -1, cosH <= 1 else { return nil }
        return radToDeg(acos(cosH))
    }

    /// Minutes after local midnight for a rising or setting event at `altitude`.
    private static func eventMinutes(
        jdMidnight: Double,
        latitude: Double,
        longitude: Double,
        tzOffsetMinutes: Double,
        altitude: Double,
        rising: Bool,
        seedMinutes: Double
    ) -> Double? {
        // Iterate twice: evaluate declination/EoT at the approximate event time.
        var minutes = seedMinutes
        for _ in 0..<2 {
            let t = julianCentury(jdMidnight + minutes / 1440)
            let (decl, eq) = declinationAndEquationOfTime(t)
            guard let ha = hourAngle(latitude: latitude, declination: decl, altitude: altitude) else {
                return nil
            }
            let delta = rising ? -ha : ha
            minutes = 720 + 4 * (delta - longitude) - eq + tzOffsetMinutes
        }
        return minutes
    }
}
