import Foundation

struct CricketMatch: Codable, Equatable {
    static let ballsPerOver = 6
    static let inningsBallLimit = 20 * ballsPerOver
    static let wicketLimit = 10
    static let entryRunRange = 0...99

    enum Delivery: String, CaseIterable, Identifiable {
        case legal, wide, noBall, noDelivery

        var id: Self { self }

        var title: String {
            switch self {
            case .legal: "Legal ball"
            case .wide: "Wide"
            case .noBall: "No ball"
            case .noDelivery: "No delivery"
            }
        }

        var penaltyRuns: Int { self == .wide || self == .noBall ? 1 : 0 }
    }

    struct Innings: Codable, Equatable {
        let batting: Scoreboard.Side
        fileprivate(set) var runs = 0
        fileprivate(set) var wickets = 0
        fileprivate(set) var balls = 0

        var score: String { "\(runs)/\(wickets)" }
        var overs: String { "\(balls / CricketMatch.ballsPerOver).\(balls % CricketMatch.ballsPerOver)" }
        var ballsRemaining: Int { max(0, CricketMatch.inningsBallLimit - balls) }
        var isComplete: Bool { ballsRemaining == 0 || wickets >= CricketMatch.wicketLimit }
        var hasStarted: Bool { runs > 0 || wickets > 0 || balls > 0 }
    }

    enum Result: Equatable {
        case won(Scoreboard.Side)
        case tied
    }

    private struct Position: Codable, Equatable {
        var first = Innings(batting: .away)
        var chase: Innings?
    }

    private var position = Position()
    private var history: [Position] = []

    var innings: Innings { position.chase ?? position.first }
    var firstBatting: Scoreboard.Side { position.first.batting }
    var isChase: Bool { position.chase != nil }
    var canChooseFirstBatting: Bool { !isChase && !position.first.hasStarted }
    var canStartChase: Bool { !isChase && position.first.isComplete }
    var canRecord: Bool { result == nil && !innings.isComplete }
    var canUndo: Bool { !history.isEmpty }
    var target: Int? { position.first.isComplete ? position.first.runs + 1 : nil }

    var result: Result? {
        guard let chase = position.chase else { return nil }
        if chase.runs > position.first.runs { return .won(chase.batting) }
        guard chase.isComplete else { return nil }
        return chase.runs == position.first.runs ? .tied : .won(position.first.batting)
    }

    var status: String {
        switch result {
        case .tied: "Tied"
        case .won: "Final"
        case nil: canStartChase ? "Innings break" : isChase ? "Chase" : "1st innings"
        }
    }

    func innings(for side: Scoreboard.Side) -> Innings? {
        position.first.batting == side ? position.first : position.chase
    }

    mutating func setFirstBatting(_ side: Scoreboard.Side) {
        guard canChooseFirstBatting, side != firstBatting else { return }
        history.append(position)
        position.first = Innings(batting: side)
    }

    mutating func startChase() {
        guard canStartChase else { return }
        history.append(position)
        position.chase = Innings(batting: firstBatting == .home ? .away : .home)
    }

    mutating func record(_ delivery: Delivery, runs: Int = 0, wicket: Bool = false) {
        guard canRecord, Self.entryRunRange.contains(runs),
              delivery != .noDelivery || runs > 0 || wicket else { return }
        var updated = innings
        let (total, overflow) = updated.runs.addingReportingOverflow(runs + delivery.penaltyRuns)
        guard !overflow, total < Int.max else { return }

        updated.runs = total
        if delivery == .legal { updated.balls += 1 }
        if wicket { updated.wickets += 1 }

        history.append(position)
        if isChase { position.chase = updated }
        else { position.first = updated }
    }

    mutating func undo() {
        if let previous = history.popLast() { position = previous }
    }
}
