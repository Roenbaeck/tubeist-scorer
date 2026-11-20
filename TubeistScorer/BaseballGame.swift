import Foundation

struct BaseballGame: Codable, Equatable {
    enum Half: String, Codable {
        case top, bottom

        var battingSide: Scoreboard.Side { self == .top ? .away : .home }
        var title: String { rawValue.capitalized }
    }

    enum Base: Int, Codable, CaseIterable {
        case first = 1, second, third

        var title: String {
            switch self {
            case .first: "First base"
            case .second: "Second base"
            case .third: "Third base"
            }
        }
    }

    enum Count: String, CaseIterable, Identifiable {
        case balls, strikes, outs

        var id: Self { self }
        var title: String { rawValue.capitalized }
        var range: ClosedRange<Int> {
            switch self {
            case .balls, .outs: 0...3
            case .strikes: 0...2
            }
        }
    }

    struct Position: Codable, Equatable {
        fileprivate(set) var inning = 1
        fileprivate(set) var half = Half.top
        fileprivate(set) var balls = 0
        fileprivate(set) var strikes = 0
        fileprivate(set) var outs = 0
        fileprivate(set) var occupiedBases: Set<Base> = []
        fileprivate(set) var homeRuns = 0
        fileprivate(set) var awayRuns = 0

        func runs(for side: Scoreboard.Side) -> Int { side == .home ? homeRuns : awayRuns }

        func count(_ kind: Count) -> Int {
            switch kind {
            case .balls: balls
            case .strikes: strikes
            case .outs: outs
            }
        }

        var inningLabel: String { "\(half.title) \(inning)" }

        fileprivate mutating func clearHalf() {
            balls = 0
            strikes = 0
            outs = 0
            occupiedBases.removeAll()
        }

        fileprivate mutating func advanceHalf() {
            switch half {
            case .top:
                half = .bottom
            case .bottom:
                if inning < Int.max { inning += 1 }
                half = .top
            }
            clearHalf()
        }
    }

    private(set) var position = Position()
    private var history: [Position] = []

    var canUndo: Bool { !history.isEmpty }
    var canGoBack: Bool { position.inning > 1 || position.half == .bottom }

    mutating func setCount(_ value: Int, for kind: Count) {
        guard kind.range.contains(value) else { return }
        var next = position
        switch kind {
        case .balls:
            next.balls = value
        case .strikes:
            next.strikes = value
        case .outs:
            if value == 3 {
                next.advanceHalf()
            } else {
                next.outs = value
            }
        }
        update(to: next)
    }

    mutating func newBatter() {
        var next = position
        next.balls = 0
        next.strikes = 0
        update(to: next)
    }

    mutating func toggleBase(_ base: Base) {
        var next = position
        if next.occupiedBases.remove(base) == nil {
            next.occupiedBases.insert(base)
        }
        update(to: next)
    }

    mutating func adjustRuns(_ amount: Int, for side: Scoreboard.Side) {
        let (sum, overflow) = position.runs(for: side).addingReportingOverflow(amount)
        guard !overflow else { return }
        var next = position
        switch side {
        case .home: next.homeRuns = max(0, sum)
        case .away: next.awayRuns = max(0, sum)
        }
        update(to: next)
    }

    mutating func nextHalf() {
        var next = position
        next.advanceHalf()
        update(to: next)
    }

    mutating func previousHalf() {
        guard canGoBack else { return }
        var next = position
        if next.half == .top {
            next.inning -= 1
            next.half = .bottom
        } else {
            next.half = .top
        }
        next.clearHalf()
        update(to: next)
    }

    mutating func undo() {
        if let previous = history.popLast() { position = previous }
    }

    private mutating func update(to next: Position) {
        guard next != position else { return }
        history.append(position)
        position = next
    }
}
