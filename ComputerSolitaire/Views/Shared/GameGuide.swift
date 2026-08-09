import Foundation

/// The Rules & Scoring guide's per-variant content. Lives outside the view
/// so tests can hold the copy to the engine's actual behavior.
nonisolated enum GameGuide {
    struct Term: Identifiable {
        let term: String
        let definition: String

        var id: String { term }
    }

    struct ScoreRow: Identifiable {
        let move: String
        let points: Int
        let note: String?

        var id: String { move }

        init(move: String, points: Int, note: String? = nil) {
            self.move = move
            self.points = points
            self.note = note
        }
    }

    /// The bonus a win's time bonus starts from in every timed variant
    /// without a draw-mode choice: their sessions all score as 3-card games
    /// (`configureWastelessNewGame` and the per-variant new-game setups pin
    /// the scoring draw count to three). Klondike's basis depends on the
    /// chosen draw mode, so its copy names both constants instead.
    static var fixedWinTimeBonusStart: Int { Scoring.timedMaxBonusDrawThree }

    static func rules(for variant: GameVariant) -> [String] {
        switch variant {
        case .klondike:
            return [
                "Deal seven tableau piles: the first holds one card, the second two, and so on to seven, with only each pile's top card face up. The rest of the deck forms the stock.",
                "Build tableau piles down in alternating colors.",
                "Move any face-up card between piles along with every card stacked on it.",
                "Move Aces to the foundations as they appear, then build each suit up to King.",
                "Only Kings (with any cards stacked on them) can fill an empty tableau pile.",
                "In 1-card draw, flip one stock card at a time. In 3-card draw, flip three.",
                "When the stock is empty, recycle the waste back into it and keep going.",
                "Face-down cards turn face up when they become the top of a pile.",
                "You win by moving all 52 cards to the foundations."
            ]
        case .freecell:
            return [
                "Deal all 52 cards face up into eight cascades (four with 7 cards, four with 6 cards).",
                "Build cascades down in alternating colors.",
                "Use the four free cells as temporary storage for one card each.",
                "Build the foundations up by suit from Ace to King.",
                "Any card can move to an empty cascade.",
                "You win by moving all 52 cards to the foundations."
            ]
        case .yukon:
            return [
                "Deal seven tableau piles: the first holds one face-up card, the second hides one face-down card beneath five face-up cards, and each pile after adds one more face-down card. All 52 cards are dealt — there is no stock.",
                "Move any face-up card along with all cards on top of it, even if they are not in sequence.",
                "The moving group's bottom card must land on a card of the opposite color, one rank higher.",
                "Build the foundations up by suit from Ace to King.",
                "Only Kings (with any cards stacked on them) can fill an empty pile.",
                "Face-down cards turn face up when they become the top of a pile.",
                "You win by moving all 52 cards to the foundations."
            ]
        case .spider:
            return [
                "Deal two decks (104 cards) into ten tableau piles: six cards in each of the first four piles and five in the rest, with only the top card face up. The remaining 50 cards form the stock.",
                "A card can move onto any card one rank higher, regardless of suit. Nothing can be placed on an Ace.",
                "Several cards move together only as a face-up run of one suit in descending order.",
                "Any card or movable run can fill an empty pile.",
                "Tap the stock to deal one face-up card onto every pile. You cannot deal while any pile is empty.",
                "A completed King-to-Ace run of one suit is removed from the tableau automatically.",
                "Face-down cards turn face up when they become the top of a pile.",
                "You win by completing all eight runs."
            ]
        case .pyramid:
            return [
                "Deal 28 cards face up into a seven-row pyramid. The remaining 24 cards form the stock.",
                "Remove pairs of exposed cards whose ranks total 13. Ace counts 1, Jack 11, and Queen 12.",
                "Kings count 13 on their own and are removed singly.",
                "A card is exposed once both cards covering it are gone. A card whose only cover is its matching partner can be removed together with it.",
                "Tap the stock to draw one card to the waste — the top waste card can pair with exposed pyramid cards.",
                "When the stock runs out, recycle the waste back into it — at most twice.",
                "You win by removing all 28 pyramid cards. The stock and waste do not need to be empty."
            ]
        case .tripeaks:
            return [
                "Deal 28 cards into three overlapping peaks: three face-down rows and a face-up base row of ten. One card starts the waste, and the remaining 23 form the stock.",
                "Play any uncovered card that is one rank above or below the top waste card, regardless of suit. It becomes the new target.",
                "Ranks wrap around: a King plays on an Ace and an Ace plays on a King or a Two.",
                "A face-down card flips face up once both cards covering it are removed.",
                "Tap the stock to flip one card onto the waste. You get one pass through the stock — no recycles.",
                "You win by clearing all 28 peak cards. The stock and waste do not need to be empty."
            ]
        case .golf:
            return [
                "Deal 35 cards face up into seven columns of five. One card starts the waste, and the remaining 16 form the stock.",
                "Play any exposed column card that is one rank above or below the top waste card, regardless of suit. It becomes the new target.",
                "Ranks never wrap: an Ace connects only to a Two, and a King only to a Queen.",
                "Nothing plays on a King — once one tops the waste, flip the stock to bury it.",
                "Tap the stock to flip one card onto the waste. You get one pass through the stock — no recycles.",
                "The hole ends when you clear all 35 column cards, or when the stock is spent and nothing plays.",
                "A match is nine holes, and the lowest total wins. Switching games keeps the match — it resumes when you return to Golf."
            ]
        case .fortyThieves:
            return [
                "Deal two decks (104 cards) into ten tableau columns of four face-up cards. The remaining 64 cards form the stock.",
                "Build tableau columns down by suit, one rank at a time. Only the top card of a column can move, so sequences never move together.",
                "Any single available card — an exposed tableau card or the top waste card — can fill an empty column.",
                "Build the eight foundations up by suit from Ace to King, two per suit. Cards placed on a foundation never return to play.",
                "Tap the stock at any time to flip one card onto the waste. You get one pass through the stock — no recycles.",
                "You win by moving all 104 cards to the foundations. The game is lost when the stock is spent and no legal move remains."
            ]
        case .canfield:
            return [
                "Deal 13 cards into the reserve with the top card face up, one face-up base card onto the first foundation, and one face-up card onto each of four tableau piles. The remaining 34 cards form the stock.",
                "All four foundations start at the base card's rank and build up by suit, wrapping from King to Ace. Cards placed on a foundation never return to play.",
                "Build tableau piles down in alternating colors, wrapping from Ace to King. Piles move onto each other only as a whole, though the exposed top card can always play to a foundation.",
                "An empty tableau pile fills immediately from the reserve. Once the reserve is empty, fill empty piles with the top waste card whenever you choose.",
                "The reserve's top card is always available to play on foundations or tableau piles.",
                "Tap the stock to turn three cards onto the waste. When it runs out, tap again to turn the waste back into a new stock — redeals are unlimited.",
                "You win by moving all 52 cards to the foundations."
            ]
        case .scorpion:
            return [
                "Deal 49 cards into seven tableau piles of seven. The first four piles hide their bottom three cards face down, while the last three are fully face up. The remaining three cards form the stock.",
                "A card can move only onto the card one rank higher of its own suit. Nothing can be placed on an Ace.",
                "Move any face-up card along with all cards on top of it, even if they are not in sequence.",
                "Only Kings (with any cards stacked on them) can fill an empty pile.",
                "Tap the stock to deal its three cards face up, one onto each of the first three piles. You can deal at any time — but only once.",
                "A completed King-to-Ace run of one suit is removed from the tableau automatically.",
                "Face-down cards turn face up when they become the top of a pile.",
                "You win by completing all four runs."
            ]
        }
    }

    static func terms(for variant: GameVariant) -> [Term] {
        switch variant {
        case .klondike:
            return [
                Term(term: "Tableau", definition: "The seven play piles where you build down in alternating colors."),
                Term(term: "Foundations", definition: "Four suit piles built up from Ace to King."),
                Term(term: "Stock", definition: "The face-down draw pile."),
                Term(term: "Waste", definition: "Face-up cards drawn from the stock — only the top card is playable."),
                Term(term: "Draw mode", definition: "How many cards you draw from the stock at a time: 1-card or 3-card.")
            ]
        case .freecell:
            return [
                Term(term: "Cascade", definition: "One of eight tableau columns where all cards are face up."),
                Term(term: "Free Cell", definition: "A temporary single-card holding slot (four total)."),
                Term(term: "Foundations", definition: "Four suit piles built up from Ace to King."),
                Term(
                    term: "Supermove",
                    definition: "A multi-card move made possible by open free cells and empty cascades."
                )
            ]
        case .yukon:
            return [
                Term(term: "Tableau", definition: "The seven play piles where you build down in alternating colors."),
                Term(term: "Foundations", definition: "Four suit piles built up from Ace to King."),
                Term(
                    term: "Group move",
                    definition: "Any face-up card together with every card stacked on top of it, moved as one, even out of order."
                )
            ]
        case .spider:
            return [
                Term(term: "Tableau", definition: "The ten play piles where you build down, regardless of suit."),
                Term(
                    term: "Run",
                    definition: "Face-up cards of one suit in descending order — only runs move together."
                ),
                Term(
                    term: "Completed run",
                    definition: "A full King-to-Ace run of one suit. It leaves the tableau automatically — eight complete the game."
                ),
                Term(term: "Stock", definition: "The face-down pile that deals one card onto every tableau pile at once."),
                Term(term: "Suits", definition: "The difficulty setting: the two decks are made of 1, 2, or 4 suits, always 104 cards.")
            ]
        case .pyramid:
            return [
                Term(
                    term: "Pyramid",
                    definition: "Twenty-eight face-up cards in seven overlapping rows — a card is exposed once both cards covering it are gone."
                ),
                Term(term: "Stock", definition: "The face-down draw pile."),
                Term(term: "Waste", definition: "Face-up cards drawn from the stock — only the top card is playable."),
                Term(term: "Discard", definition: "Where removed pairs and Kings go — cards there are out of play."),
                Term(
                    term: "Recycle",
                    definition: "Turning the waste back into the stock. Pyramid allows two recycles (three passes)."
                )
            ]
        case .tripeaks:
            return [
                Term(
                    term: "Peaks",
                    definition: "Twenty-eight cards in three overlapping peaks — a card is uncovered once both cards covering it are gone, and flips face up."
                ),
                Term(term: "Stock", definition: "The face-down draw pile. You get one pass through it — no recycles."),
                Term(
                    term: "Waste",
                    definition: "The growing face-up pile — play any uncovered card one rank above or below its top."
                ),
                Term(
                    term: "Chain",
                    definition: "Consecutive discards without flipping the stock — each discard in a chain is worth one more point than the last."
                )
            ]
        case .golf:
            return [
                Term(
                    term: "Columns",
                    definition: "Seven face-up piles of five cards — only each column's exposed card may play."
                ),
                Term(term: "Stock", definition: "The face-down draw pile. You get one pass through it — no recycles."),
                Term(
                    term: "Waste",
                    definition: "The growing face-up pile — play any exposed card one rank above or below its top."
                ),
                Term(term: "Hole", definition: "One deal. Nine holes make a match."),
                Term(
                    term: "Par",
                    definition: "45 strokes for a nine-hole match. Like golf, lower is better."
                )
            ]
        case .fortyThieves:
            return [
                Term(
                    term: "Tableau",
                    definition: "Ten columns of four face-up cards — build down by suit, one card at a time."
                ),
                Term(
                    term: "Foundations",
                    definition: "Eight suit piles built up from Ace to King, two per suit. Cards placed here never return to play."
                ),
                Term(term: "Stock", definition: "The face-down draw pile. You get one pass through it — no recycles."),
                Term(
                    term: "Waste",
                    definition: "Face-up cards drawn from the stock — only the top card is playable."
                )
            ]
        case .canfield:
            return [
                Term(
                    term: "Reserve",
                    definition: "Thirteen face-down cards with the top one face up and playable. Its top card automatically fills any empty tableau pile."
                ),
                Term(
                    term: "Base card",
                    definition: "The card dealt to the first foundation — its rank starts all four foundations."
                ),
                Term(
                    term: "Tableau",
                    definition: "Four piles built down in alternating colors, wrapping from Ace to King. Piles move only as a whole."
                ),
                Term(
                    term: "Foundations",
                    definition: "Four suit piles built up from the base rank, wrapping from King to Ace. Cards placed here never return to play."
                ),
                Term(term: "Stock", definition: "The face-down draw pile. Three cards turn over at a time, with unlimited redeals."),
                Term(term: "Waste", definition: "Face-up cards drawn from the stock — only the top card is playable.")
            ]
        case .scorpion:
            return [
                Term(term: "Tableau", definition: "The seven play piles where you build down by suit."),
                Term(
                    term: "Group move",
                    definition: "Any face-up card together with every card stacked on top of it, moved as one, even out of order."
                ),
                Term(
                    term: "Completed run",
                    definition: "A full King-to-Ace run of one suit. It leaves the tableau automatically — four complete the game."
                ),
                Term(
                    term: "Stock",
                    definition: "Three face-down cards, dealt face up onto the first three piles at any time — but only once."
                )
            ]
        }
    }

    static func scoreRows(for variant: GameVariant) -> [ScoreRow] {
        switch variant {
        case .klondike:
            return [
                ScoreRow(move: "Waste to Tableau", points: Scoring.delta(for: .wasteToTableau)),
                ScoreRow(move: "Waste to Foundation", points: Scoring.delta(for: .wasteToFoundation)),
                ScoreRow(move: "Tableau to Foundation", points: Scoring.delta(for: .tableauToFoundation)),
                ScoreRow(move: "Turn over Tableau card", points: Scoring.delta(for: .turnOverTableauCard)),
                ScoreRow(move: "Foundation to Tableau", points: Scoring.delta(for: .foundationToTableau)),
                ScoreRow(move: "Recycle waste in 1-card draw", points: Scoring.delta(for: .recycleWasteInDrawOne))
            ]
        case .freecell:
            return [
                ScoreRow(move: "Move cards", points: 0, note: "FreeCell tracks time and completion."),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .yukon:
            return [
                ScoreRow(move: "Tableau to Foundation", points: Scoring.delta(for: .tableauToFoundation)),
                ScoreRow(move: "Turn over Tableau card", points: Scoring.delta(for: .turnOverTableauCard)),
                ScoreRow(move: "Foundation to Tableau", points: Scoring.delta(for: .foundationToTableau)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .spider:
            return [
                ScoreRow(
                    move: "Start of game",
                    points: Scoring.spiderInitialScore,
                    note: "Classic Spider scoring starts every game with this balance."
                ),
                ScoreRow(move: "Any move or stock deal", points: Scoring.delta(for: .spiderMove)),
                ScoreRow(move: "Complete a run", points: Scoring.delta(for: .spiderCompletedRun)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .pyramid:
            return [
                ScoreRow(move: "Remove a pair", points: Scoring.delta(for: .removePyramidPair)),
                ScoreRow(move: "Remove a King", points: Scoring.delta(for: .removePyramidKing)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .tripeaks:
            return [
                ScoreRow(
                    move: "Discard onto the waste",
                    points: Scoring.delta(for: .triPeaksChainDiscard(chainLength: 1)),
                    note: "Each consecutive discard is worth one more: 1, 2, 3…"
                ),
                ScoreRow(
                    move: "Flip a stock card",
                    points: Scoring.delta(for: .triPeaksStockFlip),
                    note: "Also resets the chain."
                ),
                ScoreRow(move: "Clear a peak", points: Scoring.delta(for: .triPeaksPeakClear)),
                ScoreRow(
                    move: "Clear the board",
                    points: Scoring.delta(for: .triPeaksBoardClear),
                    note: "Replaces the third peak's bonus."
                ),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .golf:
            return [
                ScoreRow(
                    move: "Play a card onto the waste",
                    points: Scoring.delta(for: .golfBoardPlay),
                    note: "Your score is the cards still on the board."
                ),
                ScoreRow(move: "Flip a stock card", points: 0),
                ScoreRow(
                    move: "Clear the board",
                    points: Scoring.delta(for: .golfBoardClear(remainingStockCount: 1)),
                    note: "One point per stock card left — scores below zero are the best results."
                )
            ]
        case .fortyThieves:
            return [
                ScoreRow(move: "Waste to Tableau", points: Scoring.delta(for: .wasteToTableau)),
                ScoreRow(move: "Waste to Foundation", points: Scoring.delta(for: .wasteToFoundation)),
                ScoreRow(move: "Tableau to Foundation", points: Scoring.delta(for: .tableauToFoundation)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .canfield:
            return [
                ScoreRow(move: "Waste to Tableau", points: Scoring.delta(for: .wasteToTableau)),
                ScoreRow(move: "Waste to Foundation", points: Scoring.delta(for: .wasteToFoundation)),
                ScoreRow(move: "Reserve to Tableau", points: Scoring.delta(for: .reserveToTableau)),
                ScoreRow(move: "Reserve to Foundation", points: Scoring.delta(for: .reserveToFoundation)),
                ScoreRow(move: "Tableau to Foundation", points: Scoring.delta(for: .tableauToFoundation)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        case .scorpion:
            return [
                ScoreRow(move: "Turn over Tableau card", points: Scoring.delta(for: .turnOverTableauCard)),
                ScoreRow(move: "Complete a run", points: Scoring.delta(for: .scorpionCompletedRun)),
                ScoreRow(
                    move: "Win time bonus",
                    points: fixedWinTimeBonusStart,
                    note: "Reduced by elapsed time."
                )
            ]
        }
    }

    /// The captions under the scoring table. Golf explains its stroke score.
    /// Klondike's time bonus depends on the chosen draw mode, so its copy
    /// names both starting values; every other timed variant has no draw
    /// choice and always starts from the same bonus.
    static func scoringFootnotes(for variant: GameVariant) -> [String] {
        if variant.lowerScoreIsBetter {
            return [
                "Golf scores run like golf: lower is better, there is no time bonus, "
                    + "and negative hole scores are possible after clearing the board."
            ]
        }
        let timeBonus: String
        if variant.hasSelectableDrawMode {
            timeBonus = "Time bonus starts at \(Scoring.timedMaxBonusDrawOne) in 1-card draw and "
                + "\(Scoring.timedMaxBonusDrawThree) in 3-card draw, then drops by "
                + "\(Scoring.timedPointsLostPerSecond) point per second."
        } else {
            timeBonus = "Time bonus starts at \(fixedWinTimeBonusStart), then drops by "
                + "\(Scoring.timedPointsLostPerSecond) point per second."
        }
        return [
            "When you win, a time bonus is added.",
            timeBonus,
            "Score cannot go below \(Scoring.minimumScore)."
        ]
    }
}
