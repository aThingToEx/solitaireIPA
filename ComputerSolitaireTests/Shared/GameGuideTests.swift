import XCTest
@testable import Computer_Solitaire

/// Holds the Rules & Scoring guide's copy to the engine's actual behavior,
/// so one variant's guide can never describe another game's mechanics.
@MainActor
final class GameGuideTests: XCTestCase {

    /// Every string the guide shows for a variant, across all three tabs.
    private func guideCopy(for variant: GameVariant) -> [String] {
        var copy = GameGuide.rules(for: variant)
        for term in GameGuide.terms(for: variant) {
            copy.append(term.term)
            copy.append(term.definition)
        }
        for row in GameGuide.scoreRows(for: variant) {
            copy.append(row.move)
            if let note = row.note {
                copy.append(note)
            }
        }
        copy.append(contentsOf: GameGuide.scoringFootnotes(for: variant))
        return copy
    }

    // Only Klondike lets the player pick a draw mode, so only its guide may
    // talk about one — this is the regression the guide once had, where every
    // variant's scoring footnote described Klondike's 1-card/3-card bonus.
    func testDrawModeLanguageAppearsOnlyInKlondikesGuide() {
        let drawModePhrases = ["1-card", "3-card", "draw mode"]
        for variant in GameVariant.allCases where !variant.hasSelectableDrawMode {
            for text in guideCopy(for: variant) {
                for phrase in drawModePhrases {
                    XCTAssertFalse(
                        text.localizedCaseInsensitiveContains(phrase),
                        "\(variant.title)'s guide mentions \"\(phrase)\": \(text)"
                    )
                }
            }
        }
    }

    func testKlondikeFootnotesNameBothDrawModeBonuses() {
        let footnotes = GameGuide.scoringFootnotes(for: .klondike).joined(separator: " ")
        XCTAssertTrue(footnotes.contains("\(Scoring.timedMaxBonusDrawOne) in 1-card draw"))
        XCTAssertTrue(footnotes.contains("\(Scoring.timedMaxBonusDrawThree) in 3-card draw"))
    }

    // Deals a real game of every mode and checks the bonus its guide
    // advertises against the bonus the session would actually award.
    func testAdvertisedWinTimeBonusMatchesEveryModesGame() {
        SessionTestHarness.withIsolatedStatsStore {
            for mode in GameMode.allCases {
                let viewModel = SessionTestHarness.makeViewModel()
                viewModel.newGame(mode: mode)
                let variant = mode.variant

                if variant.lowerScoreIsBetter {
                    XCTAssertEqual(
                        viewModel.winTimeMaxBonus, 0,
                        "\(mode.displayTitle) should award no win time bonus"
                    )
                    continue
                }

                let advertised = mode.drawMode.map { Scoring.timedMaxBonus(for: $0.rawValue) }
                    ?? GameGuide.fixedWinTimeBonusStart
                XCTAssertEqual(
                    viewModel.winTimeMaxBonus, advertised,
                    "\(mode.displayTitle) advertises a bonus its games do not award"
                )
                XCTAssertTrue(
                    GameGuide.scoringFootnotes(for: variant).joined(separator: " ").contains("\(advertised)"),
                    "\(mode.displayTitle)'s footnotes never state its \(advertised) bonus"
                )
            }
        }
    }

    // Timed variants without a draw choice list the bonus as a scoring row;
    // Klondike's footnote covers both of its bases instead, and Golf has none.
    func testWinTimeBonusRowsMatchTheFixedBonus() {
        for variant in GameVariant.allCases {
            let bonusRow = GameGuide.scoreRows(for: variant).first { $0.move == "Win time bonus" }
            if variant.lowerScoreIsBetter || variant.hasSelectableDrawMode {
                XCTAssertNil(bonusRow, "\(variant.title) should not list a single win time bonus row")
            } else {
                XCTAssertEqual(
                    bonusRow?.points, GameGuide.fixedWinTimeBonusStart,
                    "\(variant.title)'s win time bonus row disagrees with the fixed bonus"
                )
            }
        }
    }

    func testGolfFootnotesExplainStrokeScoring() {
        let footnotes = GameGuide.scoringFootnotes(for: .golf).joined(separator: " ")
        XCTAssertTrue(footnotes.contains("lower is better"))
        XCTAssertTrue(footnotes.contains("no time bonus"))
    }

    func testOnlyKlondikeOffersADrawModeChoice() {
        for variant in GameVariant.allCases {
            XCTAssertEqual(variant.hasSelectableDrawMode, variant == .klondike)
        }
        for mode in GameMode.allCases {
            XCTAssertEqual(
                mode.drawMode != nil, mode.variant.hasSelectableDrawMode,
                "\(mode.displayTitle)'s draw mode disagrees with its variant's capability"
            )
        }
    }

    func testEveryVariantHasGuideContent() {
        for variant in GameVariant.allCases {
            XCTAssertFalse(GameGuide.rules(for: variant).isEmpty)
            XCTAssertFalse(GameGuide.terms(for: variant).isEmpty)
            XCTAssertFalse(GameGuide.scoreRows(for: variant).isEmpty)
            XCTAssertFalse(GameGuide.scoringFootnotes(for: variant).isEmpty)
        }
    }

    // The guide's lists drive `ForEach` by term, move, and the strings
    // themselves, so duplicates would collide as view identifiers.
    func testGuideEntriesAreUniquePerVariant() {
        for variant in GameVariant.allCases {
            let termIDs = GameGuide.terms(for: variant).map(\.id)
            XCTAssertEqual(Set(termIDs).count, termIDs.count, "\(variant.title) repeats a term")
            let rowIDs = GameGuide.scoreRows(for: variant).map(\.id)
            XCTAssertEqual(Set(rowIDs).count, rowIDs.count, "\(variant.title) repeats a scoring move")
            let rules = GameGuide.rules(for: variant)
            XCTAssertEqual(Set(rules).count, rules.count, "\(variant.title) repeats a rule")
            let footnotes = GameGuide.scoringFootnotes(for: variant)
            XCTAssertEqual(Set(footnotes).count, footnotes.count, "\(variant.title) repeats a footnote")
        }
    }
}
