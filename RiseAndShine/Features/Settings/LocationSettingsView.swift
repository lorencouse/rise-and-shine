import SwiftUI
import RiseCore

struct LocationSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [SavedLocation] = []
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                if let loc = model.settings.location {
                    LabeledContent(loc.name, value: Formatters.coordinate(loc.latitude, loc.longitude))
                    if loc.followsDevice {
                        Label("Following your device", systemImage: "location.fill").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No location set").foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        do { try await model.useDeviceLocation(); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                } label: {
                    Label(model.location.isLocating ? "Locating…" : "Use my current location", systemImage: "location")
                }
                .disabled(model.location.isLocating)
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.horizon) }
            } header: {
                Text("Current")
            } footer: {
                Text("When following your device, the app re-checks your location each time it opens, so alarms adjust when you travel.")
            }

            if !model.settings.savedPlaces.isEmpty {
                Section {
                    ForEach(model.settings.savedPlaces, id: \.self) { place in
                        Button {
                            model.setLocation(place)
                        } label: {
                            HStack {
                                Label(place.name, systemImage: "mappin").foregroundStyle(.primary)
                                Spacer()
                                if model.settings.location == place {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.sunrise)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(model.settings.location == place ? .isSelected : [])
                    }
                    .onDelete { offsets in
                        for i in offsets { model.forgetPlace(model.settings.savedPlaces[i]) }
                    }
                } header: {
                    Text("Saved places")
                } footer: {
                    Text("Cities you've picked before. Swipe to remove.")
                }
            }

            Section("Or choose a city") {
                TextField("Search for a city", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, q in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            guard !Task.isCancelled else { return }
                            results = await model.location.search(q)
                        }
                    }
                ForEach(results, id: \.self) { place in
                    Button {
                        model.setLocation(place)
                        query = ""
                        results = []
                    } label: {
                        HStack {
                            Text(place.name).foregroundStyle(.primary)
                            Spacer()
                            Text(Formatters.coordinate(place.latitude, place.longitude)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint("Sets this as your location")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.night)
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
    }
}
