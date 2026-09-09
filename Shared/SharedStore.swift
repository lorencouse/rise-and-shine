import Foundation
import RiseCore

/// Reads and writes the JSON documents both the app and the widget share.
/// Falls back to the app's Documents directory if the App Group container is unavailable
/// (e.g. when running without the entitlement in a quick simulator build).
nonisolated struct SharedStore: Sendable {
    static let shared = SharedStore()

    // Computed so the struct stays Sendable (JSONEncoder/Decoder are not).
    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func url(for file: String) -> URL {
        if let shared = AppGroup.url(for: file) { return shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(file)
    }

    func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: file)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to file: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: url(for: file), options: .atomic)
    }

    func delete(_ file: String) {
        try? FileManager.default.removeItem(at: url(for: file))
    }

    // Convenience accessors

    func loadSettings() -> AlarmSettings? {
        load(AlarmSettings.self, from: AppGroup.settingsFile)
    }

    func loadPlan() -> [PlannedDay] {
        load([PlannedDay].self, from: AppGroup.planFile) ?? []
    }
}
