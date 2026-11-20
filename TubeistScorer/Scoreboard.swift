import Foundation

struct Scoreboard: Codable, Equatable {
    static let overlayScaleRange = 0.25...2.0

    enum Sport: String, Codable, CaseIterable, Identifiable {
        case volleyball, basketball, handball, floorball, soccer, tableTennis, badminton, tennis
        case squash, futsal, padel, iceHockey
        case beachVolleyball, basketball3x3, americanFootball, baseball, cricket
        case fieldHockey, rugbyUnion
        case netball, pickleball

        var id: Self { self }

        var title: String {
            switch self {
            case .tableTennis: "Table tennis"
            case .iceHockey: "Ice hockey"
            case .beachVolleyball: "Beach volleyball"
            case .basketball3x3: "3×3 basketball"
            case .americanFootball: "American football"
            case .cricket: "T20 cricket"
            case .fieldHockey: "Field hockey"
            case .rugbyUnion: "Rugby union"
            default: rawValue.capitalized
            }
        }
        var storageKey: String { self == .volleyball ? "scoreboard" : "scoreboard." + rawValue }

        func period(_ number: Int) -> GamePeriod? {
            guard number > 0 else { return nil }
            switch self {
            case .volleyball, .tableTennis, .badminton, .tennis, .squash, .padel, .beachVolleyball, .baseball, .cricket,
                 .pickleball:
                return nil
            case .basketball3x3:
                return number == 1 ? GamePeriod("3×3", spoken: "Regulation", start: 10 * 60, stop: 0) : nil
            case .basketball:
                if number <= 4 {
                    return GamePeriod("Q\(number)", spoken: "Quarter \(number)", start: 10 * 60, stop: 0)
                }
                let overtime = number - 4
                return GamePeriod(overtime == 1 ? "OT" : "\(overtime)OT",
                                  spoken: "Overtime \(overtime)", start: 5 * 60, stop: 0)
            case .americanFootball:
                if number <= 4 {
                    return GamePeriod("Q\(number)", spoken: "Quarter \(number)", start: 15 * 60, stop: 0, showsTenths: false)
                }
                let overtime = number - 4
                return GamePeriod(overtime == 1 ? "OT" : "\(overtime)OT",
                                  spoken: "Overtime \(overtime)", start: 10 * 60, stop: 0, showsTenths: false)
            case .handball:
                if number <= 2 {
                    let start = (number - 1) * 30 * 60
                    return GamePeriod("\(number)H", spoken: "Half \(number)", start: start, stop: start + 30 * 60)
                }
                guard number <= 6 else { return nil }
                let overtime = (number - 3) / 2 + 1
                let half = (number - 3) % 2 + 1
                let start = (60 + (number - 3) * 5) * 60
                return GamePeriod("OT\(overtime) H\(half)", spoken: "Overtime \(overtime), half \(half)",
                                  start: start, stop: start + 5 * 60)
            case .floorball:
                if number <= 3 {
                    return GamePeriod("P\(number)", spoken: "Period \(number)", start: 0, stop: 20 * 60)
                }
                return number == 4 ? GamePeriod("OT", spoken: "Overtime", start: 0, stop: 10 * 60) : nil
            case .soccer, .futsal:
                let isFutsal = self == .futsal
                let stop: Int? = isFutsal ? 0 : nil
                switch number {
                case 1...2:
                    let start = isFutsal ? 20 * 60 : (number - 1) * 45 * 60
                    return GamePeriod("\(number)H", spoken: "Half \(number)", start: start, stop: stop)
                case 3...4:
                    let half = number - 2
                    let start = isFutsal ? 5 * 60 : (90 + (half - 1) * 15) * 60
                    return GamePeriod("ET\(half)", spoken: "Extra time, half \(half)", start: start, stop: stop)
                default:
                    return nil
                }
            case .iceHockey:
                if number <= 3 {
                    return GamePeriod("P\(number)", spoken: "Period \(number)", start: 20 * 60, stop: 0)
                }
                let overtime = number - 3
                return GamePeriod(overtime == 1 ? "OT" : "\(overtime)OT",
                                  spoken: "Overtime \(overtime)", start: 5 * 60, stop: 0)
            case .fieldHockey, .netball:
                guard number <= 4 else { return nil }
                return GamePeriod("Q\(number)", spoken: "Quarter \(number)", start: 15 * 60, stop: 0, showsTenths: false)
            case .rugbyUnion:
                guard number <= 2 else { return nil }
                return GamePeriod("\(number)H", spoken: "Half \(number)", start: (number - 1) * 40 * 60)
            }
        }
    }

    struct GamePeriod {
        let label: String
        let accessibilityLabel: String
        let start: Int
        let stop: Int?
        let showsTenths: Bool

        init(_ label: String, spoken: String, start: Int, stop: Int? = nil, showsTenths: Bool = true) {
            self.label = label
            accessibilityLabel = spoken
            self.start = start
            self.stop = stop
            self.showsTenths = stop == 0 && showsTenths
        }

        var countsDown: Bool { stop == 0 }
        var maximumClockSeconds: TimeInterval {
            if let stop, !countsDown { return TimeInterval(stop) }
            return TimedGame.maximumClockSeconds
        }
    }

    enum Side: String, Codable {
        case home, away

        var title: String {
            switch self {
            case .home: "Home"
            case .away: "Away"
            }
        }
    }

    enum Theme: String, CaseIterable, Codable, Identifiable {
        case modern, arena, courtside, retro, daylight, legacy

        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    struct Team: Codable, Equatable {
        var name: String
        var rgb: UInt32
        var points = 0
        var sets = 0
    }

    struct TimedGame: Codable, Equatable {
        static let maximumClockSeconds: TimeInterval = 199 * 60 + 59.9

        struct Clock: Encodable {
            let seconds: TimeInterval
            let startedAt: TimeInterval?
            let countsDown: Bool
            let showsTenths: Bool
            let maximumSeconds: TimeInterval

            func time(at date: Date) -> TimeInterval {
                let elapsed = startedAt.map { max(0, date.timeIntervalSince1970 - $0) } ?? 0
                return min(maximumSeconds, max(0, seconds + (countsDown ? -elapsed : elapsed)))
            }

            func canRun(at date: Date) -> Bool {
                let time = time(at: date)
                return countsDown ? time > 0 : time < maximumSeconds
            }

            func isRunning(at date: Date) -> Bool {
                startedAt != nil && canRun(at: date)
            }

            func displayTenths(at date: Date) -> Int {
                let time = time(at: date)
                if showsTenths { return Int(ceil(time * 10)) }
                let seconds = countsDown ? ceil(time) : floor(time)
                return Int(seconds) * 10
            }

            func label(at date: Date) -> String {
                let tenths = displayTenths(at: date)
                if showsTenths, tenths < 600 { return "\(tenths / 10).\(tenths % 10)" }
                let seconds = (tenths + 9) / 10
                return String(format: "%d:%02d", seconds / 60, seconds % 60)
            }
        }

        private(set) var period = 1
        private var clockSeconds: TimeInterval
        private var clockStartedAt: TimeInterval?

        init?(sport: Sport) {
            guard let firstPeriod = sport.period(1) else { return nil }
            clockSeconds = TimeInterval(firstPeriod.start)
        }

        private enum CodingKeys: String, CodingKey { case period, clockSeconds, clockStartedAt }
        private enum LegacyClockKeys: String, CodingKey { case clockEndsAt }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            period = try values.decode(Int.self, forKey: .period)
            clockSeconds = try values.decode(TimeInterval.self, forKey: .clockSeconds)
            clockStartedAt = try values.decodeIfPresent(TimeInterval.self, forKey: .clockStartedAt)
            if clockStartedAt == nil {
                let legacy = try decoder.container(keyedBy: LegacyClockKeys.self)
                if let deadline = try legacy.decodeIfPresent(TimeInterval.self, forKey: .clockEndsAt) {
                    clockStartedAt = deadline - clockSeconds
                }
            }
        }

        func clock(in period: GamePeriod) -> Clock {
            Clock(seconds: clockSeconds, startedAt: clockStartedAt, countsDown: period.countsDown,
                  showsTenths: period.showsTenths, maximumSeconds: period.maximumClockSeconds)
        }

        mutating func toggleClock(at date: Date, in period: GamePeriod) {
            let current = clock(in: period)
            if current.isRunning(at: date) {
                setClock(seconds: current.time(at: date), in: period)
            } else if current.canRun(at: date) {
                clockStartedAt = date.timeIntervalSince1970
            }
        }

        mutating func setClock(seconds: TimeInterval, in period: GamePeriod) {
            clockStartedAt = nil
            clockSeconds = min(period.maximumClockSeconds, max(0, seconds))
        }

        mutating func changePeriod(by amount: Int, for sport: Sport, at date: Date) {
            let (next, overflow) = period.addingReportingOverflow(amount)
            guard !overflow, let currentPeriod = sport.period(period), let nextPeriod = sport.period(next),
                  !clock(in: currentPeriod).isRunning(at: date) else { return }
            period = next
            setClock(seconds: TimeInterval(nextPeriod.start), in: nextPeriod)
        }
    }

    var home = Team(name: "Home team", rgb: 0x1B6ACF)
    var away = Team(name: "Away team", rgb: 0xBF3B40)
    var serving: Side?
    var theme: Theme = .modern
    private(set) var sport: Sport
    var timedGame: TimedGame?
    var footballGame: FootballGame?
    var baseballGame: BaseballGame?
    var cricketMatch: CricketMatch?
    var rallyMatch: RallyMatch?
    private(set) var threeOnThree: ThreeOnThree?
    private var overlayScale: Double?

    init(sport: Sport = .volleyball) {
        self.sport = sport
        timedGame = TimedGame(sport: sport)
        rallyMatch = RallyMatch(sport: sport)
        if sport == .basketball3x3 { threeOnThree = ThreeOnThree() }
        if sport == .americanFootball { footballGame = FootballGame() }
        if sport == .baseball { baseballGame = BaseballGame() }
        if sport == .cricket { cricketMatch = CricketMatch() }
        if rallyMatch != nil, sport != .pickleball {
            let entry = sport == .padel || sport == .beachVolleyball ? "pair" : "player"
            home.name = "Home " + entry
            away.name = "Away " + entry
        }
    }

    private enum CodingKeys: String, CodingKey {
        case home, away, serving, theme, sport, timedGame, threeOnThree, footballGame, baseballGame, cricketMatch, overlayScale
        case rallyMatch = "racketMatch"
    }
    private enum LegacyMatchKeys: String, CodingKey { case basketball }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        home = try values.decode(Team.self, forKey: .home)
        away = try values.decode(Team.self, forKey: .away)
        serving = try values.decodeIfPresent(Side.self, forKey: .serving)
        theme = try values.decode(Theme.self, forKey: .theme)
        overlayScale = try values.decodeIfPresent(Double.self, forKey: .overlayScale)

        let legacy = try decoder.container(keyedBy: LegacyMatchKeys.self)
        let basketball = try legacy.decodeIfPresent(TimedGame.self, forKey: .basketball)
        sport = try values.decodeIfPresent(Sport.self, forKey: .sport) ?? (basketball == nil ? .volleyball : .basketball)
        let savedRally = try values.decodeIfPresent(RallyMatch.self, forKey: .rallyMatch)
        rallyMatch = savedRally.flatMap { $0.format.sport == sport ? $0 : nil } ?? RallyMatch(sport: sport)
        if sport == .basketball3x3 {
            threeOnThree = try values.decodeIfPresent(ThreeOnThree.self, forKey: .threeOnThree) ?? ThreeOnThree()
        }
        if sport == .americanFootball {
            footballGame = try values.decodeIfPresent(FootballGame.self, forKey: .footballGame) ?? FootballGame()
        }
        if sport == .baseball {
            baseballGame = try values.decodeIfPresent(BaseballGame.self, forKey: .baseballGame) ?? BaseballGame()
        }
        if sport == .cricket {
            cricketMatch = try values.decodeIfPresent(CricketMatch.self, forKey: .cricketMatch) ?? CricketMatch()
        }
        let savedGame = try values.decodeIfPresent(TimedGame.self, forKey: .timedGame) ?? basketball
        if let savedGame, sport.period(savedGame.period) != nil {
            timedGame = savedGame
        } else {
            timedGame = TimedGame(sport: sport)
        }
    }

    var overlayScaleFactor: Double {
        get { Self.normalizedOverlayScale(overlayScale ?? 1) }
        set {
            let scale = Self.normalizedOverlayScale(newValue)
            overlayScale = scale == 1 ? nil : scale
        }
    }

    private static func normalizedOverlayScale(_ scale: Double) -> Double {
        guard scale.isFinite else { return 1 }
        return min(overlayScaleRange.upperBound, max(overlayScaleRange.lowerBound, scale))
    }

    subscript(side: Side) -> Team {
        get {
            switch side {
            case .home: home
            case .away: away
            }
        }
        set {
            switch side {
            case .home: home = newValue
            case .away: away = newValue
            }
        }
    }

    mutating func adjustPoints(_ amount: Int, for side: Side) {
        self[side].points = max(0, self[side].points + amount)
        if amount > 0 && sport == .volleyball { serving = side }
    }

    mutating func adjustSets(_ amount: Int, for side: Side) {
        self[side].sets = max(0, self[side].sets + amount)
    }

    mutating func resetPoints() {
        home.points = 0
        away.points = 0
        serving = nil
    }

    mutating func resetMatch() {
        resetPoints()
        home.sets = 0
        away.sets = 0
        timedGame = TimedGame(sport: sport)
        rallyMatch?.reset()
        if threeOnThree != nil { threeOnThree = ThreeOnThree() }
        if footballGame != nil { footballGame = FootballGame() }
        if baseballGame != nil { baseballGame = BaseballGame() }
        if cricketMatch != nil { cricketMatch = CricketMatch() }
    }

    struct FootballGame: Codable, Equatable {
        enum Down: Int, Codable, CaseIterable, Identifiable {
            case first = 1, second, third, fourth

            var id: Self { self }
            var title: String {
                switch self {
                case .first: "1st"
                case .second: "2nd"
                case .third: "3rd"
                case .fourth: "4th"
                }
            }
        }

        enum Score: String {
            case touchdown, fieldGoal, extraPoint, twoPointConversion, safety

            var title: String {
                switch self {
                case .touchdown: "TD"
                case .fieldGoal: "FG"
                case .extraPoint: "XP"
                case .twoPointConversion: "2PT"
                case .safety: "Safety"
                }
            }

            var accessibilityTitle: String {
                switch self {
                case .touchdown: "touchdown"
                case .fieldGoal: "field goal"
                case .extraPoint: "extra point"
                case .twoPointConversion: "two-point conversion"
                case .safety: "safety"
                }
            }

            var points: Int {
                switch self {
                case .touchdown: 6
                case .fieldGoal: 3
                case .extraPoint: 1
                case .twoPointConversion, .safety: 2
                }
            }
        }

        static let yardRange = 1...99

        var possession: Side?
        var down = Down.first
        var yardsToGo = 10
        var goalToGo = false

        var situation: String? {
            guard possession != nil else { return nil }
            return "\(down.title) & \(goalToGo ? "Goal" : String(yardsToGo))"
        }

        mutating func firstAndTen() {
            down = .first
            yardsToGo = 10
            goalToGo = false
        }
    }

    enum RugbyScore: String {
        case tryScore, conversion, penaltyGoal, dropGoal, penaltyTry

        var title: String {
            switch self {
            case .tryScore: "Try"
            case .conversion: "Conversion"
            case .penaltyGoal: "Penalty goal"
            case .dropGoal: "Drop goal"
            case .penaltyTry: "Penalty try"
            }
        }

        var points: Int {
            switch self {
            case .tryScore: 5
            case .conversion: 2
            case .penaltyGoal, .dropGoal: 3
            case .penaltyTry: 7
            }
        }
    }

    struct ThreeOnThree: Codable, Equatable {
        fileprivate enum Change: Codable, Equatable {
            case basket(Side, Int)
            case overtime
        }

        fileprivate(set) var overtimeTarget: Int?
        fileprivate var history: [Change] = []
        var canUndo: Bool { !history.isEmpty }
    }

    var finishedThreeOnThreeByScore: Bool {
        guard let threeOnThree else { return false }
        return max(home.points, away.points) >= (threeOnThree.overtimeTarget ?? 21)
    }

    private var threeOnThreeBuzzerStatus: String { home.points == away.points ? "Tied" : "Final" }

    func threeOnThreeStatus(at date: Date) -> String {
        if finishedThreeOnThreeByScore { return "Final" }
        if threeOnThree?.overtimeTarget != nil { return "Overtime" }
        if let clock = threeOnThreeRegulationClock, clock.time(at: date) == 0 { return threeOnThreeBuzzerStatus }
        return "Regulation"
    }

    private var threeOnThreeRegulationClock: TimedGame.Clock? {
        guard threeOnThree != nil, let timedGame, let period = sport.period(1) else { return nil }
        return timedGame.clock(in: period)
    }

    func canStartThreeOnThreeOvertime(at date: Date) -> Bool {
        threeOnThree != nil && threeOnThree?.overtimeTarget == nil && !finishedThreeOnThreeByScore
            && home.points == away.points && threeOnThreeRegulationClock?.time(at: date) == 0
    }

    mutating func startThreeOnThreeOvertime(at date: Date) {
        guard canStartThreeOnThreeOvertime(at: date), let period = sport.period(1) else { return }
        timedGame?.setClock(seconds: 0, in: period)
        threeOnThree?.overtimeTarget = home.points + 2
        threeOnThree?.history.append(.overtime)
    }

    mutating func awardThreeOnThreeBasket(_ points: Int, for side: Side, at date: Date) {
        guard threeOnThree != nil, !finishedThreeOnThreeByScore, (1...2).contains(points) else { return }
        self[side].points += points
        threeOnThree?.history.append(.basket(side, points))
        if finishedThreeOnThreeByScore, threeOnThree?.overtimeTarget == nil,
           let period = sport.period(1), let clock = threeOnThreeRegulationClock {
            timedGame?.setClock(seconds: clock.time(at: date), in: period)
        }
    }

    mutating func undoThreeOnThreeChange() {
        switch threeOnThree?.history.popLast() {
        case let .basket(side, points): self[side].points -= points
        case .overtime: threeOnThree?.overtimeTarget = nil
        case nil: break
        }
    }

    func overlayUpdateData() throws -> Data {
        let game: OverlayUpdate.Game?
        if let threeOnThree, let clock = threeOnThreeRegulationClock {
            let finished = finishedThreeOnThreeByScore
            let overtime = threeOnThree.overtimeTarget != nil
            game = OverlayUpdate.Game(
                period: finished ? "Final" : overtime ? "OT" : "3×3",
                clock: overtime ? nil : clock,
                statusAtZero: finished || overtime ? nil : threeOnThreeBuzzerStatus
            )
        } else if let timedGame, let period = sport.period(timedGame.period) {
            game = OverlayUpdate.Game(
                period: period.label, clock: timedGame.clock(in: period),
                possession: footballGame?.possession, situation: footballGame?.situation
            )
        } else {
            game = nil
        }
        let racket = rallyMatch.map { match in
            OverlayUpdate.Racket(home: racketScore(for: .home, match: match),
                                 away: racketScore(for: .away, match: match), status: match.status)
        }
        let baseball = baseballGame.map {
            let position = $0.position
            return OverlayUpdate.Baseball(inning: position.inningLabel, batting: position.half.battingSide, balls: position.balls,
                                          strikes: position.strikes, outs: position.outs,
                                          bases: BaseballGame.Base.allCases.filter(position.occupiedBases.contains))
        }
        let cricket = cricketMatch.map {
            OverlayUpdate.Cricket(
                homeScore: $0.innings(for: .home)?.score ?? "–",
                awayScore: $0.innings(for: .away)?.score ?? "–",
                batting: $0.canRecord ? $0.innings.batting : nil,
                overs: $0.innings.overs, status: $0.status, target: $0.target
            )
        }
        var home = home
        var away = away
        if let baseballGame {
            home.points = baseballGame.position.homeRuns
            away.points = baseballGame.position.awayRuns
        }
        return try JSONEncoder().encode(
            OverlayUpdate(home: home, away: away, serving: serving, theme: theme,
                          overlayScale: overlayScale, game: game, racket: racket, baseball: baseball, cricket: cricket)
        )
    }

    private func racketScore(for side: Side, match: RallyMatch) -> OverlayUpdate.Racket.RallyScore {
        let score = match[side]
        return OverlayUpdate.Racket.RallyScore(
            points: match.pointLabel(for: side), games: match.hasGames ? score.games : nil,
            sets: match.hasSets ? score.sets : nil, serving: match.serving == side,
            serverNumber: match.serving == side ? match.pickleballServerNumber : nil
        )
    }

    private struct OverlayUpdate: Encodable {
        struct Game: Encodable {
            let period: String
            let clock: TimedGame.Clock?
            var statusAtZero: String? = nil
            var possession: Side? = nil
            var situation: String? = nil
        }

        struct Baseball: Encodable {
            let inning: String
            let batting: Side
            let balls: Int
            let strikes: Int
            let outs: Int
            let bases: [BaseballGame.Base]
        }

        struct Cricket: Encodable {
            let homeScore: String
            let awayScore: String
            let batting: Side?
            let overs: String
            let status: String
            let target: Int?
        }

        struct Racket: Encodable {
            struct RallyScore: Encodable {
                let points: String
                let games: Int?
                let sets: Int?
                let serving: Bool
                let serverNumber: Int?
            }

            let home: RallyScore
            let away: RallyScore
            let status: String?
        }

        let home: Team
        let away: Team
        let serving: Side?
        let theme: Theme
        let overlayScale: Double?
        let game: Game?
        let racket: Racket?
        let baseball: Baseball?
        let cricket: Cricket?
    }
}
