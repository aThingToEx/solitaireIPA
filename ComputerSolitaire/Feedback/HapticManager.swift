import Observation
import SwiftUI
#if os(iOS)
import CoreHaptics
#endif

@MainActor
@Observable
final class HapticManager {
    static let shared = HapticManager()

    /// False on iPads: they have no Taptic Engine.
    static let deviceSupportsHaptics: Bool = {
#if os(iOS)
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
#else
        false
#endif
    }()

    enum Event {
        case cardPickUp
        case cardPlaced
        case stockDraw
        case wasteRecycle
        case cardFlipFaceUp
        case runCompleted
        case invalidDrop
        case undoMove
        case hintFound
        case settingsSelection
        case gameSwitched
        case dropTargetAcquired
        case autoFinishStart
        case golfHoleDead
        case destructiveActionConfirmed
        case gameWon
    }

    private(set) var trigger: UInt64 = 0
    private var pendingEvent: Event?
    private var isCoalescingTick = false

    private init() {}

    /// SwiftUI plays `sensoryFeedback` once per view update, so same-tick
    /// calls collapse into one sensation; the highest-ranking event wins.
    func play(_ event: Event) {
#if os(iOS)
        guard isHapticFeedbackEnabled else { return }
        if isCoalescingTick {
            if event.coalescingRank > (pendingEvent?.coalescingRank ?? Int.min) {
                pendingEvent = event
            }
        } else {
            pendingEvent = event
            isCoalescingTick = true
            Task { @MainActor in
                self.isCoalescingTick = false
            }
        }
        trigger &+= 1
#endif
    }

    private var isHapticFeedbackEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: SettingsKey.hapticFeedbackEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: SettingsKey.hapticFeedbackEnabled)
    }

    var feedbackForTrigger: SensoryFeedback? {
#if os(iOS)
        return pendingEvent?.sensoryFeedback
#else
        return nil
#endif
    }
}

private extension HapticManager.Event {
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .cardPickUp:
            return .impact(flexibility: .soft, intensity: 0.6)
        case .cardPlaced:
            return .impact(flexibility: .rigid, intensity: 0.6)
        case .stockDraw:
            return .impact(weight: .light)
        case .wasteRecycle:
            return .impact(weight: .medium)
        case .cardFlipFaceUp:
            return .selection
        case .runCompleted:
            return .success
        case .invalidDrop:
            return .error
        case .undoMove:
            return .selection
        case .hintFound:
            return .selection
        case .settingsSelection:
            return .selection
        case .gameSwitched:
            return .selection
        case .dropTargetAcquired:
            return .selection
        case .autoFinishStart:
            return .impact(weight: .medium)
        case .golfHoleDead:
            return .warning
        case .destructiveActionConfirmed:
            return .warning
        case .gameWon:
            return .success
        }
    }

    /// Outcomes beat impacts beat selection ticks.
    var coalescingRank: Int {
        switch self {
        case .gameWon, .runCompleted:
            return 3
        case .invalidDrop, .golfHoleDead, .destructiveActionConfirmed:
            return 2
        case .cardPickUp, .cardPlaced, .stockDraw, .wasteRecycle, .autoFinishStart:
            return 1
        case .cardFlipFaceUp, .undoMove, .hintFound, .settingsSelection,
             .gameSwitched, .dropTargetAcquired:
            return 0
        }
    }
}
