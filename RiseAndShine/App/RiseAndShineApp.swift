import SwiftUI
import RiseCore

@main
struct RiseAndShineApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.sunrise)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.settings.onboardingCompleted {
                Task { await model.refresh() }
            }
        }
        .backgroundTask(.appRefresh(AppGroup.backgroundRefreshTask)) {
            await model.refresh()
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.settings.onboardingCompleted {
            HomeView()
        } else {
            OnboardingFlow()
        }
    }
}
