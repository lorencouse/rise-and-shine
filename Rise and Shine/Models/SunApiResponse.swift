//
//  SunApiResponse.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation

struct SunApiResponse: Decodable {
    let results: [SunData]
    let status: String
    enum CodingKeys: String, CodingKey {
        case results
        case status
    }
}
