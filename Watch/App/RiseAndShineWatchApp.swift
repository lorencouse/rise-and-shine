import SwiftUI

@main
struct RiseAndShineWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(model)
                .tint(WatchTheme.sunrise)
        }
    }
}

enum WatchTheme {
    static let sunrise = Color(red: 0.98, green: 0.62, blue: 0.24)
    static let sun = Color(red: 1.00, green: 0.84, blue: 0.45)
    static let moon = Color(red: 0.62, green: 0.70, blue: 0.98)
    static let faint = Color.white.opacity(0.5)
}
