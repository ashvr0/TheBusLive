import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Central place for triggering haptic feedback across the app.
///
/// All haptics route through here so they can be globally disabled from
/// Settings via `AppPreferenceKeys.hapticsEnabled`. Screens should call
/// `HapticsManager.shared.<event>()` rather than talking to
/// `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`
/// directly, so the preference is respected everywhere automatically.
@MainActor
final class HapticsManager {

    static let shared = HapticsManager()

    private init() {}

    /// Whether haptics are enabled, read live from the same UserDefaults
    /// key the Settings toggle uses. Defaults to `true` when unset.
    private var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: AppPreferenceKeys.hapticsEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: AppPreferenceKeys.hapticsEnabled)
    }

    #if canImport(UIKit)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    #endif

    /// A light tap, for low-emphasis actions like tapping a map pin or a
    /// row selection.
    func light() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
        #endif
    }

    /// A medium tap, for standard button presses and toggles.
    func medium() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
        #endif
    }

    /// A crisp, rigid tap, used for drag-reorder "pickup"/"drop" moments.
    func rigid() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        rigidGenerator.prepare()
        rigidGenerator.impactOccurred()
        #endif
    }

    /// Feedback for picking something as a favorite / a positive
    /// confirmation.
    func success() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    /// Feedback for a destructive or negative outcome, like removing a
    /// favorite or a failed request.
    func warning() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }

    /// A discrete "tick", used for moving through a picker/segmented
    /// control or crossing a reorder position.
    func selectionChanged() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
        #endif
    }
}
