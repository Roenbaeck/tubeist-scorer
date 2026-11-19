import Foundation

struct Scoreboard: Codable, Equatable {
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

    var home = Team(name: "Home team", rgb: 0x1B6ACF)
    var away = Team(name: "Away team", rgb: 0xBF3B40)
    var serving: Side?
    var theme: Theme = .modern

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
        if amount > 0 {
            serving = side
        }
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
    }
}
