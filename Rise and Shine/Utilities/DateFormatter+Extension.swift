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
    
    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static func fetchDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }

    static func formattedTimeString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        return dateFormatter.string(from: date)
    }

    static func formattedDateString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }
    
    static func removeSecondsTimeString(timeString: String) -> String? {
        // DateFormatter to parse the input string
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "h:mm:ss a"
        
        // DateFormatter to format the output string
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        
        // Attempt to parse the input string into a Date object
        if let date = inputFormatter.date(from: timeString) {
            // Format the Date object into the desired output string format
            return outputFormatter.string(from: date)
        } else {
            // Return nil if the input string couldn't be parsed
            return nil
        }
    }
    
}

extension String {
//    func dropSecondsFromTime() -> String {
//        // Split the string into components using space as a separator to separate time from AM/PM if present.
//        let parts = self.components(separatedBy: " ")
//        
//        // Further split the first part (the time) by colon to separate hours, minutes, and seconds.
//        if var timeComponents = parts.first?.components(separatedBy: ":") {
//            // Check if there are at least three components (hours, minutes, and seconds).
//            if timeComponents.count == 3 {
//                // Remove the seconds component.
//                timeComponents.removeLast()
//                
//                // Rejoin the time components without seconds, and add back the AM/PM part if it was present.
//                let timeWithoutSeconds = timeComponents.joined(separator: ":") + (parts.count > 1 ? " \(parts[1])" : "")
//                
//                return timeWithoutSeconds
//            }
//        }
//        
//        // Return the original string if it doesn't match the expected format.
//        return self
//    }
    

        func dropSecondsFromTime() -> String {
            let parts = self.components(separatedBy: " ")
            if var timeComponents = parts.first?.components(separatedBy: ":") {
                if timeComponents.count == 3 {
                    timeComponents.removeLast()
                    let timeWithoutSeconds = timeComponents.joined(separator: ":") + (parts.count > 1 ? " \(parts[1])" : "")
                    return timeWithoutSeconds
                }
            }
            return self
        }
    
    
    
    func convertToTimeWithoutSeconds() -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd h:mm:ss a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        // Set to the appropriate timezone for your input data. Example: TimeZone.current for the device's current timezone
        inputFormatter.timeZone = TimeZone.current

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        // Ensure output formatter uses the same timezone as the input formatter to maintain the original time
        outputFormatter.timeZone = inputFormatter.timeZone

        if let date = inputFormatter.date(from: self) {
            return outputFormatter.string(from: date)
        } else {
            return "Conversion Failed"
        }
    }
    
}






