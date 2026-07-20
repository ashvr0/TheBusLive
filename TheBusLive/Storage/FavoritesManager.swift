import Foundation
import Combine

/// Metadata for a favorited stop, including user-added notes.
struct FavoriteStopMetadata: Codable, Hashable {
    let stop: Stop
    /// User-provided note like "home -> work" or "work -> home"
    let note: String

    var id: String { stop.id }

    init(stop: Stop, note: String = "") {
        self.stop = stop
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Persists favorite and recently-viewed stops locally via UserDefaults.
/// The storage keys below only matter if you need to match existing on-device data exactly.
///
/// Thread Safety: Marked @MainActor to ensure all state mutations happen on the main thread.
@MainActor
final class FavoritesManager: ObservableObject {

    @Published private(set) var favorites: [FavoriteStopMetadata] = []
    @Published private(set) var recents: [Stop] = []

    private let favoritesKey = "com.thebuslive.favorites"
    private let recentsKey = "com.thebuslive.recents"
    private let maxRecents = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ stop: Stop) -> Bool {
        favorites.contains { $0.stop == stop }
    }

    func getNoteForFavorite(_ stop: Stop) -> String {
        favorites.first { $0.stop == stop }?.note ?? ""
    }

    func toggleFavorite(_ stop: Stop, note: String = "") {
        if let index = favorites.firstIndex(where: { $0.stop == stop }) {
            favorites.remove(at: index)
            HapticsManager.shared.warning()
        } else {
            let metadata = FavoriteStopMetadata(stop: stop, note: note)
            favorites.append(metadata)
            HapticsManager.shared.success()
        }
        saveFavorites()
    }

    func updateNote(_ stop: Stop, to newNote: String) {
        guard let index = favorites.firstIndex(where: { $0.stop == stop }) else {
            return
        }
        favorites[index] = FavoriteStopMetadata(stop: stop, note: newNote)
        saveFavorites()
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        saveFavorites()
        HapticsManager.shared.warning()
    }

    /// Reorders favorites in place, used to back drag-to-reorder in
    /// `FavoritesView`. `IndexSet`/`Int` signature matches
    /// `ForEach.onMove` directly.
    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
        HapticsManager.shared.rigid()
    }

    func recordRecent(_ stop: Stop) {
        recents.removeAll { $0 == stop }
        recents.insert(stop, at: 0)
        if recents.count > maxRecents {
            recents.removeLast(recents.count - maxRecents)
        }
        saveRecents()
    }

    func clearRecents() {
        recents = []
        saveRecents()
    }

    // MARK: - Private persistence methods

    private func load() {
        favorites = decodeFavorites()
        recents = decodeRecents()
    }

    private func decodeFavorites() -> [FavoriteStopMetadata] {
        guard let data = defaults.data(forKey: favoritesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([FavoriteStopMetadata].self, from: data)
        } catch {
            NSLog("Error decoding favorites: \(error)")
            return []
        }
    }

    private func decodeRecents() -> [Stop] {
        guard let data = defaults.data(forKey: recentsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([Stop].self, from: data)
        } catch {
            NSLog("Error decoding recents: \(error)")
            return []
        }
    }

    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else {
            NSLog("Error encoding favorites")
            return
        }
        defaults.set(data, forKey: favoritesKey)
    }

    private func saveRecents() {
        guard let data = try? JSONEncoder().encode(recents) else {
            NSLog("Error encoding recents")
            return
        }
        defaults.set(data, forKey: recentsKey)
    }
}