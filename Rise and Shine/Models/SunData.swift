//
//  SunData.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation

struct SunData: Decodable {
    let date: String
    let sunrise: String
    let sunset: String
    let firstLight: String
    let lastLight: String
    let dawn: String
    let dusk: String
    let solarNoon: String
    let goldenHour: String
    let dayLength: String
    let timezone: String
    let utcOffset: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case sunrise
        case sunset
        case firstLight = "first_light"
        case lastLight = "last_light"
        case dawn
        case dusk
        case solarNoon = "solar_noon"
        case goldenHour = "golden_hour"
        case dayLength = "day_length"
        case timezone
        case utcOffset = "utc_offset"
    }
}
