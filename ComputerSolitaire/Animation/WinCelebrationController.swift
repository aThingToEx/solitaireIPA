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

    /// Launch-time snapshot the overlay builds its Canvas symbols from.
    /// Replacing it is what triggers a re-render; the live `cards` below
    /// are invisible to observation.
    private(set) var launchStates: [WinCascadeCardState] = []
    private(set) var hiddenFoundationCardIDs: Set<UUID> = []
    private(set) var phase: Phase = .idle

    /// Live simulation state. Unobserved: the Canvas renderer reads it
    /// untracked, and its per-frame mutation must not schedule updates on
    /// top of the TimelineView's own.
    @ObservationIgnored private(set) var cards: [WinCascadeCardState] = []
    @ObservationIgnored private var lastTickDate: Date?
    @ObservationIgnored private var isCompletionScheduled = false
    /// Keeps a deferred completion from landing on a later cascade.
    @ObservationIgnored private var cascadeGeneration = 0

    var isAnimating: Bool {
        phase == .animating
    }

    /// Advances the physics by real elapsed time, once per display frame
    /// from the Canvas renderer, so a slow frame skips ahead instead of
    /// stretching the cascade into slow motion.
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

        WinCascadeCoordinator.advance(
            states: &cards,
            by: deltaTime,
            boardBounds: boardBounds
        )

        if !cards.isEmpty, !isCompletionScheduled, cards.allSatisfy(\.isSettled) {
            // Defer the observable phase flip out of the render pass.
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
