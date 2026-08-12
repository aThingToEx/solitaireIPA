import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class WinCelebrationController {
    enum Phase: Equatable {
        case idle
        case animating
        case completed
    }

    /// Immutable snapshot of the cascade's cards taken at launch (faces and
    /// sizes never change in flight). The overlay builds its Canvas symbols
    /// from this, and replacing it is what tells SwiftUI a new cascade — or a
    /// resynced settled pile — needs rendering; the live `cards` below stay
    /// invisible to observation.
    private(set) var launchStates: [WinCascadeCardState] = []
    private(set) var hiddenFoundationCardIDs: Set<UUID> = []
    private(set) var phase: Phase = .idle

    /// Live simulation state, advanced by `tick` once per display frame.
    /// Outside observation on purpose: the cascade Canvas reads it from its
    /// renderer closure (untracked), and the per-frame mutation must not
    /// schedule a second SwiftUI update on top of the TimelineView's own.
    @ObservationIgnored private(set) var cards: [WinCascadeCardState] = []
    @ObservationIgnored private var lastTickDate: Date?
    @ObservationIgnored private var isCompletionScheduled = false
    /// Bumped whenever the cascade's lifecycle restarts, so a completion
    /// deferred from `tick` can never land on a different cascade than the
    /// one that settled.
    @ObservationIgnored private var cascadeGeneration = 0

    var isAnimating: Bool {
        phase == .animating
    }

    /// Advances the physics by the real time elapsed since the previous
    /// frame. Called from the cascade Canvas renderer on each TimelineView
    /// frame, so the simulation runs at the display's native cadence (120 Hz
    /// on ProMotion) and a slow frame skips ahead instead of stretching the
    /// animation into slow motion — `step` clamps the delta to keep the
    /// physics stable across hitches.
    func tick(at date: Date, boardBounds: CGRect) {
        guard phase == .animating else { return }
        guard let previousTickDate = lastTickDate else {
            // First frame draws the launch positions as-is.
            lastTickDate = date
            return
        }
        let deltaTime = date.timeIntervalSince(previousTickDate)
        lastTickDate = date
        guard deltaTime > 0 else { return }

        WinCascadeCoordinator.step(
            states: &cards,
            deltaTime: deltaTime,
            boardBounds: boardBounds
        )

        if !cards.isEmpty, !isCompletionScheduled, cards.allSatisfy(\.isSettled) {
            // The renderer is no place to publish observable state — defer
            // the phase flip to the next main-actor turn.
            isCompletionScheduled = true
            let generation = cascadeGeneration
            Task { @MainActor [weak self] in
                guard let self,
                      self.cascadeGeneration == generation,
                      self.phase == .animating else { return }
                self.phase = .completed
            }
        }
    }

    /// `launchPiles` are the piles the cascade erupts from, with `launchTargets`
    /// naming each pile's on-board drop target (aligned by index): the four
    /// foundations for the build-up variants, the discard for Pyramid.
    func beginIfNeededForWin(
        launchPiles: [[Card]],
        launchTargets: [DropTarget],
        dropFrames: [DropTarget: DropTargetGeometry],
        boardViewportSize: CGSize
    ) {
        guard phase == .idle else { return }
        begin(
            launchPiles: launchPiles,
            launchTargets: launchTargets,
            hiddenLaunchCardIDs: Self.launchCardIDs(from: launchPiles),
            dropFrames: dropFrames,
            boardViewportSize: boardViewportSize
        )
    }

    func reset(to phase: Phase = .idle) {
        cascadeGeneration += 1
        cards = []
        launchStates = []
        hiddenFoundationCardIDs = []
        lastTickDate = nil
        isCompletionScheduled = false
        self.phase = phase
    }

    func syncForLoadedGame(
        launchPiles: [[Card]],
        launchTargets: [DropTarget],
        isWin: Bool,
        dropFrames: [DropTarget: DropTargetGeometry],
        boardViewportSize: CGSize
    ) {
        cascadeGeneration += 1
        lastTickDate = nil
        isCompletionScheduled = false
        if isWin {
            let completedCards = completedStatesForLoadedWin(
                launchPiles: launchPiles,
                launchTargets: launchTargets,
                dropFrames: dropFrames,
                boardViewportSize: boardViewportSize
            )
            cards = completedCards
            launchStates = completedCards
            hiddenFoundationCardIDs = completedCards.isEmpty
                ? []
                : Self.launchCardIDs(from: launchPiles)
            phase = .completed
        } else {
            cards = []
            launchStates = []
            hiddenFoundationCardIDs = []
            phase = .idle
        }
    }

    private func begin(
        launchPiles: [[Card]],
        launchTargets: [DropTarget],
        hiddenLaunchCardIDs: Set<UUID>,
        dropFrames: [DropTarget: DropTargetGeometry],
        boardViewportSize: CGSize
    ) {
        self.hiddenFoundationCardIDs = hiddenLaunchCardIDs
        let boardBounds = CGRect(origin: .zero, size: boardViewportSize)
        guard boardBounds.width > 0, boardBounds.height > 0 else {
            phase = .completed
            return
        }

        let launchFrames = Self.launchFrames(for: launchTargets, dropFrames: dropFrames)
        let fallbackLaunchFrame = Self.fallbackLaunchFrame(
            launchFrames: launchFrames,
            boardBounds: boardBounds
        )

        let initialStates = WinCascadeCoordinator.makeInitialStates(
            foundations: launchPiles,
            foundationFrames: launchFrames,
            fallbackLaunchFrame: fallbackLaunchFrame
        )
        guard !initialStates.isEmpty else {
            phase = .completed
            return
        }

        cascadeGeneration += 1
        cards = initialStates
        launchStates = initialStates
        lastTickDate = nil
        isCompletionScheduled = false
        phase = .animating
    }

    private static func launchCardIDs(from launchPiles: [[Card]]) -> Set<UUID> {
        Set(launchPiles.flatMap { pile in pile.map(\.id) })
    }

    private static func launchFrames(
        for launchTargets: [DropTarget],
        dropFrames: [DropTarget: DropTargetGeometry]
    ) -> [Int: CGRect] {
        var launchFrames: [Int: CGRect] = [:]
        for (index, target) in launchTargets.enumerated() {
            if let frame = dropFrames[target]?.snapFrame, frame != .zero {
                launchFrames[index] = frame
            }
        }
        return launchFrames
    }

    private static func fallbackLaunchFrame(
        launchFrames: [Int: CGRect],
        boardBounds: CGRect
    ) -> CGRect {
        launchFrames[0]
            ?? launchFrames.values.first
            ?? CGRect(
                x: boardBounds.midX - 50,
                y: max(0, boardBounds.height * 0.22 - 72),
                width: 100,
                height: 145
            )
    }

    private func completedStatesForLoadedWin(
        launchPiles: [[Card]],
        launchTargets: [DropTarget],
        dropFrames: [DropTarget: DropTargetGeometry],
        boardViewportSize: CGSize
    ) -> [WinCascadeCardState] {
        let boardBounds = CGRect(origin: .zero, size: boardViewportSize)
        guard boardBounds.width > 0, boardBounds.height > 0 else { return [] }

        let launchFrames = Self.launchFrames(for: launchTargets, dropFrames: dropFrames)
        let fallbackLaunchFrame = Self.fallbackLaunchFrame(
            launchFrames: launchFrames,
            boardBounds: boardBounds
        )

        return WinCascadeCoordinator.makeCompletedStates(
            foundations: launchPiles,
            foundationFrames: launchFrames,
            fallbackLaunchFrame: fallbackLaunchFrame,
            boardBounds: boardBounds
        )
    }

}
