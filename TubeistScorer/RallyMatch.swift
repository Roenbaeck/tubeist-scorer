import Foundation

struct RallyMatch: Codable, Equatable {
    enum Format: String, Codable, Identifiable, CaseIterable {
        case tableTennis3, tableTennis5, tableTennis7
        case badminton21, badminton15
        case tennis3, tennis5
        case squash3, squash5
        case padelStar, padelGolden, padelAdvantage
        case beachVolleyball
        case pickleballDoubles, pickleballSingles

        var id: Self { self }

        var sport: Scoreboard.Sport {
            switch self {
            case .tableTennis3, .tableTennis5, .tableTennis7: .tableTennis
            case .badminton21, .badminton15: .badminton
            case .tennis3, .tennis5: .tennis
            case .squash3, .squash5: .squash
            case .padelStar, .padelGolden, .padelAdvantage: .padel
            case .beachVolleyball: .beachVolleyball
            case .pickleballDoubles, .pickleballSingles: .pickleball
            }
        }

        var title: String {
            switch self {
            case .tableTennis3, .squash3: "Best of 3 games"
            case .tableTennis5, .squash5: "Best of 5 games"
            case .tableTennis7: "Best of 7 games"
            case .badminton21: "21-point games"
            case .badminton15: "15-point games"
            case .tennis3: "Best of 3 sets"
            case .tennis5: "Best of 5 sets"
            case .padelStar: "Star Point"
            case .padelGolden: "Golden Point"
            case .padelAdvantage: "Advantage"
            case .beachVolleyball: "Best of 3 sets"
            case .pickleballDoubles: "Doubles"
            case .pickleballSingles: "Singles"
            }
        }

        var winsNeeded: Int {
            switch self {
            case .tableTennis3, .badminton21, .badminton15, .tennis3, .squash3,
                 .padelStar, .padelGolden, .padelAdvantage, .beachVolleyball, .pickleballDoubles, .pickleballSingles: 2
            case .tableTennis5, .tennis5, .squash5: 3
            case .tableTennis7: 4
            }
        }
    }

    struct Score: Codable, Equatable {
        fileprivate(set) var points = 0
        fileprivate(set) var games = 0
        fileprivate(set) var sets = 0
    }

    private struct PickleballService: Codable, Equatable {
        var side: Scoreboard.Side
        var isSecondServer: Bool
    }

    private struct Position: Codable, Equatable {
        var home = Score()
        var away = Score()
        var gameServer: Scoreboard.Side?
        var pickleballService: PickleballService?

        subscript(side: Scoreboard.Side) -> Score {
            get { side == .home ? home : away }
            set {
                switch side {
                case .home: home = newValue
                case .away: away = newValue
                }
            }
        }
    }

    private(set) var format: Format
    private var position = Position()
    private var history: [Position] = []

    init?(sport: Scoreboard.Sport) {
        switch sport {
        case .tableTennis: format = .tableTennis5
        case .badminton: format = .badminton21
        case .tennis: format = .tennis3
        case .squash: format = .squash5
        case .padel: format = .padelStar
        case .beachVolleyball: format = .beachVolleyball
        case .pickleball: format = .pickleballDoubles
        default: return nil
        }
    }

    subscript(side: Scoreboard.Side) -> Score { position[side] }

    var canUndo: Bool { !history.isEmpty }
    var canChangeFormat: Bool {
        position.home == Score() && position.away == Score() && position.pickleballService == nil
    }

    var winner: Scoreboard.Side? {
        if winningUnits(for: .home) >= format.winsNeeded { return .home }
        if winningUnits(for: .away) >= format.winsNeeded { return .away }
        return nil
    }

    private var usesTennisPoints: Bool { format.sport == .tennis || format.sport == .padel }
    var hasSets: Bool { usesTennisPoints || format == .beachVolleyball }
    var hasGames: Bool { format != .beachVolleyball }

    private var beachSet: Int { position.home.sets + position.away.sets + 1 }
    private var beachTarget: Int { beachSet == 3 ? 15 : 21 }

    var isTiebreak: Bool {
        usesTennisPoints && position.home.games == 6 && position.away.games == 6
    }

    private var decidingPoint: String? {
        guard usesTennisPoints, !isTiebreak, position.home.points == position.away.points else { return nil }
        switch (format, position.home.points) {
        case (.padelGolden, 3): return "Golden Point"
        case (.padelStar, 5): return "Star Point"
        default: return nil
        }
    }

    var status: String? {
        if winner != nil { return "Final" }
        if format == .beachVolleyball { return "Set \(beachSet) · To \(beachTarget)" }
        if isTiebreak { return "Tiebreak" }
        if let decidingPoint { return decidingPoint }
        if usesTennisPoints, position.home.points >= 3, position.home.points == position.away.points {
            return "Deuce"
        }
        return nil
    }

    var serving: Scoreboard.Side? {
        guard winner == nil else { return nil }
        if let service = position.pickleballService { return service.side }
        guard let server = position.gameServer else { return nil }
        return isReceivingSideTurn ? server.opponent : server
    }

    var pickleballServerNumber: Int? {
        guard format == .pickleballDoubles, winner == nil, let service = position.pickleballService else { return nil }
        return service.isSecondServer ? 2 : 1
    }

    func pointLabel(for side: Scoreboard.Side) -> String {
        let points = position[side].points
        guard usesTennisPoints else { return String(points) }
        guard winner == nil else { return "–" }
        if isTiebreak { return String(points) }
        switch points {
        case 0: return "0"
        case 1: return "15"
        case 2: return "30"
        default: return points > 3 && points > position[side.opponent].points ? "AD" : "40"
        }
    }

    mutating func setFormat(_ newFormat: Format) {
        guard canChangeFormat, newFormat.sport == format.sport else { return }
        format = newFormat
    }

    mutating func setServer(_ side: Scoreboard.Side) {
        guard winner == nil, serving != side else { return }
        if format.sport == .pickleball {
            guard position.pickleballService == nil else { return }
            history.append(position)
            startGame(server: side)
            return
        }
        history.append(position)
        position.gameServer = isReceivingSideTurn ? side.opponent : side
    }

    mutating func recordRally(wonBy side: Scoreboard.Side) {
        guard winner == nil else { return }
        if format.sport == .pickleball {
            guard let service = position.pickleballService else { return }
            if service.side != side {
                history.append(position)
                if format == .pickleballDoubles, !service.isSecondServer {
                    position.pickleballService?.isSecondServer = true
                } else {
                    position.pickleballService = PickleballService(side: side, isSecondServer: false)
                }
                return
            }
        }
        let isDecidingPoint = decidingPoint != nil
        history.append(position)
        position[side].points += 1
        let points = position[side].points
        let lead = points - position[side.opponent].points

        switch format {
        case .tableTennis3, .tableTennis5, .tableTennis7, .pickleballDoubles, .pickleballSingles:
            if points >= 11, lead >= 2 {
                finishGame(winner: side, nextServer: position.gameServer?.opponent)
            }
        case .badminton21, .badminton15:
            position.gameServer = side
            let target = format == .badminton21 ? 21 : 15
            let cap = format == .badminton21 ? 30 : 21
            if points >= cap || (points >= target && lead >= 2) {
                finishGame(winner: side, nextServer: side)
            }
        case .squash3, .squash5:
            position.gameServer = side
            if points >= 11, lead >= 2 {
                finishGame(winner: side, nextServer: side)
            }
        case .beachVolleyball:
            position.gameServer = side
            if points >= beachTarget, lead >= 2 {
                position[side].sets += 1
                if winner == nil { startGame(server: nil) }
            }
        case .tennis3, .tennis5, .padelStar, .padelGolden, .padelAdvantage:
            let tiebreak = isTiebreak
            if isDecidingPoint || (points >= (tiebreak ? 7 : 4) && lead >= 2) {
                finishSetGame(winner: side, tiebreak: tiebreak)
            }
        }
    }

    mutating func undo() {
        if let previous = history.popLast() { position = previous }
    }

    mutating func reset() {
        position = Position()
        history.removeAll()
    }

    private var isReceivingSideTurn: Bool {
        let total = position.home.points + position.away.points
        switch format.sport {
        case .tableTennis:
            let turns = total < 20 ? total / 2 : total - 10
            return !turns.isMultiple(of: 2)
        case .tennis, .padel:
            return isTiebreak && !((total + 1) / 2).isMultiple(of: 2)
        default:
            return false
        }
    }

    private func winningUnits(for side: Scoreboard.Side) -> Int {
        hasSets ? position[side].sets : position[side].games
    }

    private mutating func finishGame(winner side: Scoreboard.Side, nextServer: Scoreboard.Side?) {
        position[side].games += 1
        if winner == nil { startGame(server: nextServer) }
    }

    private mutating func finishSetGame(winner side: Scoreboard.Side, tiebreak: Bool) {
        position[side].games += 1
        if tiebreak || (position[side].games >= 6 && position[side].games - position[side.opponent].games >= 2) {
            position[side].sets += 1
            if winner == nil {
                position.home.games = 0
                position.away.games = 0
            }
        }
        if winner == nil { startGame(server: position.gameServer?.opponent) }
    }

    private mutating func startGame(server: Scoreboard.Side?) {
        position.home.points = 0
        position.away.points = 0
        position.gameServer = server
        if format.sport == .pickleball {
            // The opening side gets a single server before the first side-out of each game.
            position.pickleballService = server.map {
                PickleballService(side: $0, isSecondServer: format == .pickleballDoubles)
            }
        }
    }
}

private extension Scoreboard.Side {
    var opponent: Self { self == .home ? .away : .home }
}
