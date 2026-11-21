//
//  DealGenerator.swift
//  MaemelSolitaer
//
//  Produces deals that are guaranteed to be winnable. Each random deal is searched by a
//  compact solver, and the solution it finds is replayed move by move through the real
//  `KlondikeGame` rules. Only deals that replay to a full win are handed to the player.
//

import Foundation

nonisolated struct DealConfig: Hashable, Sendable {
    let difficulty: Difficulty
    let drawCount: Int
    let stage: StageKind
}

nonisolated enum DealGenerator {
    /// Returns a shuffled deal proven to be winnable. Runs synchronously — call it off the main actor.
    static func makeWinnableDeal(_ config: DealConfig, timeBudget: Duration = .seconds(10)) -> KlondikeGame {
        let clock = ContinuousClock()
        let start = clock.now
        let difficulty = config.difficulty
        let band = difficulty.winRateBand(for: config.stage)
        // Nearest-to-band deal proven winnable so far, used if no deal lands in the band in time.
        var best: (game: KlondikeGame, distance: Double)?

        while clock.now - start < timeBudget && !Task.isCancelled {
            let game = KlondikeGame.deal(columns: difficulty.columnCount, decks: difficulty.deckCount,
                                         drawCount: config.drawCount)
            // How many choice sequences win? Measured by random play (cheap), before the proof.
            let rate = KlondikeSolver.winRate(game, playouts: difficulty.measurePlayouts)
            let distance = rate < band.lowerBound ? band.lowerBound - rate
                : (rate > band.upperBound ? rate - band.upperBound : 0)
            guard distance == 0 || distance < (best?.distance ?? .infinity) else { continue }

            if let solution = KlondikeSolver.solve(game, nodeLimit: difficulty.solverNodeLimit),
               KlondikeSolver.replay(solution, on: game) {
                if distance == 0 { return game }
                best = (game, distance)
            }
        }
        return best?.game ?? constructedDeal(config)
    }

    /// Fallback that is winnable by construction: every column is ordered so its top card is the
    /// next one needed, and the deck is arranged so the needed card is always on top of the waste.
    /// Only used if no random deal could be proven winnable within the time budget.
    static func constructedDeal(_ config: DealConfig) -> KlondikeGame {
        let difficulty = config.difficulty
        var game = KlondikeGame.deal(columns: difficulty.columnCount, decks: difficulty.deckCount,
                                     drawCount: config.drawCount)
        // The order in which cards go up to the foundations.
        func playOrder(_ card: Card) -> Int { (card.rank - 1) * 8 + card.suit.rawValue * 2 + card.deck }

        for t in game.tableau.indices {
            var column = game.tableau[t].sorted { playOrder($0) > playOrder($1) }
            for i in column.indices { column[i].isFaceUp = i == column.count - 1 }
            game.tableau[t] = column
        }

        // Within each group of drawn cards, the earliest-needed card must land on top of the waste.
        let stockInOrder = game.stock.sorted { playOrder($0) < playOrder($1) }
        var draws: [Card] = []
        var i = 0
        while i < stockInOrder.count {
            let end = min(i + config.drawCount, stockInOrder.count)
            draws.append(contentsOf: stockInOrder[i..<end].reversed())
            i = end
        }
        game.stock = draws.reversed().map { card in
            var card = card
            card.isFaceUp = false
            return card
        }
        return game
    }
}

nonisolated enum SolverMove: Sendable {
    case draw
    case move(from: PileID, index: Int, to: PileID)
}

/// Depth-first Klondike solver on a compact state. Mirrors the rules in `KlondikeGame` exactly;
/// any solution is double-checked with `replay(_:on:)`.
nonisolated struct KlondikeSolver {
    private struct State {
        var tableau: [[UInt8]]
        var faceDown: [Int]
        var stock: [UInt8]
        var waste: [UInt8]
        var foundation: [Int]

        init(_ game: KlondikeGame) {
            tableau = game.tableau.map { column in column.map { UInt8($0.id) } }
            faceDown = game.tableau.map { column in column.prefix { !$0.isFaceUp }.count }
            stock = game.stock.map { UInt8($0.id) }
            waste = game.waste.map { UInt8($0.id) }
            foundation = game.foundations.map(\.count)
        }

        var isWon: Bool { foundation.allSatisfy { $0 == 13 } }
    }

    private let drawCount: Int

    static func solve(_ game: KlondikeGame, nodeLimit: Int) -> [SolverMove]? {
        KlondikeSolver(drawCount: game.drawCount).search(from: State(game), nodeLimit: nodeLimit)
    }

    /// Plays the moves through the real rules; true only if every move is legal and the game is won.
    static func replay(_ moves: [SolverMove], on game: KlondikeGame) -> Bool {
        var game = game
        for move in moves {
            switch move {
            case .draw:
                guard game.dealFromStock() != nil else { return false }
            case .move(let from, let index, let to):
                guard game.move(from: from, at: index, to: to) != nil else { return false }
            }
        }
        return game.isWon
    }

    // MARK: - Difficulty measure

    /// Share of random-choice games that clear the board (0...1). At every step a random legal,
    /// non-repeating move is chosen; a game with no such move left is a dead end.
    /// High = many choice sequences win (easy). Near 0 = only a few exact sequences win (hard).
    static func winRate(_ game: KlondikeGame, playouts: Int) -> Double {
        KlondikeSolver(drawCount: game.drawCount).estimate(State(game), playouts: playouts)
    }

    private func estimate(_ start: State, playouts: Int) -> Double {
        var wins = 0
        for _ in 0..<playouts {
            if Task.isCancelled { break }
            var state = start
            var seen: Set<Int> = [key(state)]
            for _ in 0..<600 {
                if state.isWon { wins += 1; break }
                let next = moves(for: state)
                    .map { apply($0, to: state) }
                    .filter { !seen.contains(key($0)) }
                guard let chosen = next.randomElement() else { break }
                seen.insert(key(chosen))
                state = chosen
            }
        }
        return Double(wins) / Double(max(playouts, 1))
    }

    // MARK: - Search

    private func search(from start: State, nodeLimit: Int) -> [SolverMove]? {
        var visited = Set<Int>()
        visited.reserveCapacity(nodeLimit)
        visited.insert(key(start))

        var states: [State] = [start]
        var options: [[SolverMove]] = [moves(for: start)]
        var nextOption: [Int] = [0]
        var path: [SolverMove] = []
        var nodes = 0

        while let state = states.last {
            if state.isWon { return path }
            let depth = states.count - 1
            guard nextOption[depth] < options[depth].count else {
                // Dead end: step back.
                states.removeLast()
                options.removeLast()
                nextOption.removeLast()
                if !path.isEmpty { path.removeLast() }
                continue
            }
            let move = options[depth][nextOption[depth]]
            nextOption[depth] += 1

            let next = apply(move, to: state)
            guard visited.insert(key(next)).inserted else { continue }
            nodes += 1
            if nodes > nodeLimit { return nil }
            if nodes % 4096 == 0 && Task.isCancelled { return nil }

            path.append(move)
            states.append(next)
            options.append(moves(for: next))
            nextOption.append(0)
        }
        return nil
    }

    // MARK: - Move generation

    private func moves(for s: State) -> [SolverMove] {
        // Safe moves to the foundation are always made first and never undone.
        if let card = s.waste.last, let f = foundationSlot(for: card, in: s), isSafe(card, in: s) {
            return [.move(from: .waste, index: s.waste.count - 1, to: .foundation(f))]
        }
        for c in s.tableau.indices {
            guard let card = s.tableau[c].last, let f = foundationSlot(for: card, in: s), isSafe(card, in: s) else { continue }
            return [.move(from: .tableau(c), index: s.tableau[c].count - 1, to: .foundation(f))]
        }

        var result: [SolverMove] = []
        let firstEmpty = s.tableau.firstIndex { $0.isEmpty }

        // 1. Other moves to the foundation.
        if let card = s.waste.last, let f = foundationSlot(for: card, in: s) {
            result.append(.move(from: .waste, index: s.waste.count - 1, to: .foundation(f)))
        }
        for c in s.tableau.indices {
            guard let card = s.tableau[c].last, let f = foundationSlot(for: card, in: s) else { continue }
            result.append(.move(from: .tableau(c), index: s.tableau[c].count - 1, to: .foundation(f)))
        }

        // 2. Runs that turn over a face-down card, deepest columns first.
        let deepestFirst = s.tableau.indices.sorted { s.faceDown[$0] > s.faceDown[$1] }
        for c in deepestFirst where s.faceDown[c] > 0 {
            let index = s.faceDown[c]
            let base = s.tableau[c][index]
            appendTableauMoves(from: c, index: index, card: base, in: s, firstEmpty: firstEmpty, to: &result)
        }

        // 3. The top deck card onto a column.
        if let card = s.waste.last {
            for d in s.tableau.indices where !s.tableau[d].isEmpty && canPlace(card, on: d, in: s) {
                result.append(.move(from: .waste, index: s.waste.count - 1, to: .tableau(d)))
            }
            if Self.rank(card) == 13, let empty = firstEmpty {
                result.append(.move(from: .waste, index: s.waste.count - 1, to: .tableau(empty)))
            }
        }

        // 4. Part of a run, to free the card beneath it for the foundation.
        for c in s.tableau.indices {
            let column = s.tableau[c]
            let firstUp = s.faceDown[c]
            guard column.count - firstUp >= 2 else { continue }
            for i in (firstUp + 1)..<column.count where foundationSlot(for: column[i - 1], in: s) != nil {
                for d in s.tableau.indices where d != c && !s.tableau[d].isEmpty && canPlace(column[i], on: d, in: s) {
                    result.append(.move(from: .tableau(c), index: i, to: .tableau(d)))
                }
            }
        }

        // 5. Empty a column, but only when a King is waiting for the space.
        if firstEmpty == nil && kingIsWaiting(in: s) {
            for c in s.tableau.indices where s.faceDown[c] == 0 {
                guard let base = s.tableau[c].first, Self.rank(base) != 13 else { continue }
                for d in s.tableau.indices where d != c && !s.tableau[d].isEmpty && canPlace(base, on: d, in: s) {
                    result.append(.move(from: .tableau(c), index: 0, to: .tableau(d)))
                }
            }
        }

        // 6. Turn over deck cards.
        if !s.stock.isEmpty || !s.waste.isEmpty {
            result.append(.draw)
        }
        return result
    }

    private func appendTableauMoves(from c: Int, index: Int, card: UInt8, in s: State,
                                    firstEmpty: Int?, to result: inout [SolverMove]) {
        for d in s.tableau.indices where d != c && !s.tableau[d].isEmpty && canPlace(card, on: d, in: s) {
            result.append(.move(from: .tableau(c), index: index, to: .tableau(d)))
        }
        if Self.rank(card) == 13, let empty = firstEmpty, empty != c {
            result.append(.move(from: .tableau(c), index: index, to: .tableau(empty)))
        }
    }

    private func apply(_ move: SolverMove, to state: State) -> State {
        var s = state
        switch move {
        case .draw:
            if s.stock.isEmpty {
                s.stock = s.waste.reversed()
                s.waste.removeAll()
            } else {
                for _ in 0..<min(drawCount, s.stock.count) {
                    s.waste.append(s.stock.removeLast())
                }
            }
        case .move(let from, let index, let to):
            var cards: [UInt8] = []
            switch from {
            case .waste:
                cards = [s.waste.removeLast()]
            case .tableau(let c):
                cards = Array(s.tableau[c][index...])
                s.tableau[c].removeSubrange(index...)
                // Turn over the newly exposed card.
                if s.faceDown[c] >= s.tableau[c].count {
                    s.faceDown[c] = max(0, s.tableau[c].count - 1)
                }
            case .stock, .foundation:
                break
            }
            switch to {
            case .foundation(let f):
                s.foundation[f] += cards.count
            case .tableau(let d):
                s.tableau[d].append(contentsOf: cards)
            case .stock, .waste:
                break
            }
        }
        return s
    }

    // MARK: - Rules on card codes (code = Card.id)

    private static func suit(_ code: UInt8) -> Int { Int(code % 52) / 13 }
    private static func rank(_ code: UInt8) -> Int { Int(code % 13) + 1 }
    private static func isRed(_ code: UInt8) -> Bool { isRedSuit(suit(code)) }
    private static func isRedSuit(_ suit: Int) -> Bool { suit == 1 || suit == 2 }

    private func foundationSlot(for card: UInt8, in s: State) -> Int? {
        let suit = Self.suit(card)
        let rank = Self.rank(card)
        for f in s.foundation.indices where f % 4 == suit && s.foundation[f] == rank - 1 {
            return f
        }
        return nil
    }

    /// Safe when no card that could be built on it is still in play.
    private func isSafe(_ card: UInt8, in s: State) -> Bool {
        let rank = Self.rank(card)
        if rank <= 2 { return true }
        let red = Self.isRed(card)
        for f in s.foundation.indices where Self.isRedSuit(f % 4) != red && s.foundation[f] < rank - 1 {
            return false
        }
        return true
    }

    private func canPlace(_ card: UInt8, on column: Int, in s: State) -> Bool {
        guard let top = s.tableau[column].last else { return Self.rank(card) == 13 }
        return Self.rank(top) == Self.rank(card) + 1 && Self.isRed(top) != Self.isRed(card)
    }

    private func kingIsWaiting(in s: State) -> Bool {
        if s.stock.contains(where: { Self.rank($0) == 13 }) || s.waste.contains(where: { Self.rank($0) == 13 }) {
            return true
        }
        return s.tableau.contains { column in column.dropFirst().contains { Self.rank($0) == 13 } }
    }

    /// Position key for the visited set. Column order and duplicate cards (two decks) don't
    /// matter for whether a position can be won, so they are folded together.
    private func key(_ s: State) -> Int {
        var columnKeys = s.tableau.indices.map { c -> Int in
            var hasher = Hasher()
            hasher.combine(s.faceDown[c])
            for card in s.tableau[c] { hasher.combine(card % 52) }
            return hasher.finalize()
        }
        columnKeys.sort()
        var hasher = Hasher()
        hasher.combine(columnKeys)
        for card in s.stock { hasher.combine(card % 52) }
        hasher.combine(UInt8.max)
        for card in s.waste { hasher.combine(card % 52) }
        hasher.combine(s.foundation)
        return hasher.finalize()
    }
}
