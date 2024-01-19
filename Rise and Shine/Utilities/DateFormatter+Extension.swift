//
//  DateFormatter+Extension.swift
//  Rise and Shine
//
//  Created by loren on 1/18/24.
//

import Foundation

extension DateFormatter {

    // Example 1: Shared Date Formatter for a specific format
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // Example 2: Function to create a date formatter with a custom format
    static func customFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    static let monthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter
    }()
}
