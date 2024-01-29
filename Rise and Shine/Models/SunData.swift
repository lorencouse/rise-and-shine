//
//  SunData.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation




struct SunData: Decodable, Hashable, Encodable {
    let date: String
    let sunrise: String
    let sunset: String
    let firstLight: String
    let lastLight: String
    let dawn: String
    let dusk: String
    let dayLength: String
    
    enum CodingKeys: String, CodingKey {
        case date
        case sunrise
        case sunset
        case firstLight = "first_light"
        case lastLight = "last_light"
        case dawn
        case dusk
        case dayLength = "day_length"
    }
}

struct AlarmSchedule: Codable {
    var date: String
    var sunriseTime: String
    var alarmTime: String
    var bedTime: String
    var windDownTime: String
}



