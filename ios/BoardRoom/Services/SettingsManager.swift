import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("roleType") var roleTypeRaw: String = Director.RoleType.position.rawValue
    @AppStorage("syncTodosToReminders") var syncTodosToReminders: Bool = true

    @Published var directors: [Director] = [] {
        didSet { saveDirectors() }
    }

    var roleType: Director.RoleType {
        get { Director.RoleType(rawValue: roleTypeRaw) ?? .position }
        set { roleTypeRaw = newValue.rawValue }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    private let directorsKey = "savedDirectors"
    private let schemaVersionKey = "directorsSchemaVersion"
    private let currentSchemaVersion = 5 // Bumped for Persona Director addition

    init() {
        loadDirectors()
    }

    private func loadDirectors() {
        let savedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)

        // If schema version is outdated, reset to new defaults
        if savedVersion < currentSchemaVersion {
            directors = Director.defaults
            UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            return
        }

        if let data = UserDefaults.standard.data(forKey: directorsKey),
           let saved = try? JSONDecoder().decode([Director].self, from: data) {
            // Validate that directorKeys exist
            if saved.allSatisfy({ !$0.directorKey.isEmpty }) {
                directors = saved
            } else {
                directors = Director.defaults
            }
        } else {
            directors = Director.defaults
        }
    }

    private func saveDirectors() {
        if let data = try? JSONEncoder().encode(directors) {
            UserDefaults.standard.set(data, forKey: directorsKey)
        }
    }

    func resetDirectors() {
        directors = Director.defaults
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    var enabledDirectors: [Director] {
        directors.filter { $0.isEnabled }
    }
}
