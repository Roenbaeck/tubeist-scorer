import SwiftUI
import UIKit

struct ScoreboardView: View {
    @AppStorage("selectedSport") private var sport = Scoreboard.Sport.volleyball
    @State private var scoreboards = ScoreboardView.restoreScoreboards()
    @State private var isConfirmingReset = false
    @State private var showConnection = false
    @State private var showsOverlayScale = false
    @State private var nearbyOverlay = NearbyOverlaySender()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var activeMatch: Binding<Scoreboard> {
        let sport = sport
        return Binding {
            scoreboards[sport] ?? Scoreboard(sport: sport)
        } set: { match in
            scoreboards[sport] = match
        }
    }

    private var scoreboard: Scoreboard { activeMatch.wrappedValue }

    private var teamOrder: [Scoreboard.Side] { sport == .baseball ? [.away, .home] : [.home, .away] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LabeledContent("Sport") {
                        Picker("Sport", selection: $sport) {
                            ForEach(Scoreboard.Sport.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityIdentifier("scoring-sport")
                    }

                    overlayPreview
                    if let match = scoreboard.rallyMatch {
                        rallyControls(match)
                    }
                    if let game = Binding(activeMatch.timedGame) {
                        if sport == .basketball3x3 {
                            ThreeOnThreeControls(match: activeMatch, game: game)
                        } else {
                            GameClockControls(sport: sport, game: game)
                                .id(sport)
                        }
                    }
                    if let football = Binding(activeMatch.footballGame) {
                        FootballSituationControls(game: football)
                    }
                    if let baseball = Binding(activeMatch.baseballGame) {
                        BaseballControls(game: baseball)
                    }
                    if let cricket = Binding(activeMatch.cricketMatch) {
                        CricketControls(match: cricket, homeName: scoreboard.home.name, awayName: scoreboard.away.name)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) {
                            ForEach(teamOrder, id: \.self) { teamCard($0) }
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(teamOrder, id: \.self) { teamCard($0) }
                        }
                    }
                    Link("Privacy Policy", destination: URL(string: "https://www.uptochange.com/tubeist-scorer/privacy-policy.html")!)
                        .font(.footnote)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: 680)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tubeist Scorer")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    let indicator = nearbyOverlay.connectionState.indicator
                    Button {
                        nearbyOverlay.update(scoreboard)
                        nearbyOverlay.recheckConnection()
                        showConnection = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: indicator.symbol)
                                .foregroundStyle(indicator.color)
                            Text(indicator.title)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    .accessibilityLabel("Tubeist connection")
                    .accessibilityValue(Text(indicator.title))
                    .accessibilityHint("Opens connection controls")
                    .accessibilityIdentifier("connect-to-tubeist")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { isConfirmingReset = true }
                }
            }
            .confirmationDialog("Reset scores", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                if sport == .volleyball {
                    Button("Reset points", role: .destructive) { activeMatch.wrappedValue.resetPoints() }
                }
                Button(scoreboard.timedGame == nil ? "Reset match" : "Reset game", role: .destructive) {
                    activeMatch.wrappedValue.resetMatch()
                }
            }
        }
        .sheet(isPresented: $showConnection) {
            NearbyOverlayConnectionView(sender: nearbyOverlay)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { nearbyOverlay.recheckConnection() }
        }
        .task(id: scenePhase == .active && nearbyOverlay.isConnected) {
            guard scenePhase == .active, nearbyOverlay.isConnected else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                nearbyOverlay.recheckConnection(announcesProgress: false)
            }
        }
        .onChange(of: scoreboard) { _, updated in
            nearbyOverlay.update(updated)
        }
        .onChange(of: scoreboards) { previous, updated in
            for (sport, match) in updated where previous[sport] != match {
                if let data = try? JSONEncoder().encode(match) {
                    UserDefaults.standard.set(data, forKey: sport.storageKey)
                }
            }
        }
    }

    private var overlayPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overlay preview").font(.headline)
                Spacer()
                Button {
                    showsOverlayScale.toggle()
                } label: {
                    Label(overlayScaleLabel, systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.monospacedDigit())
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Adjust overlay scale")
                .accessibilityValue(overlayScaleLabel)
            }

            if showsOverlayScale {
                HStack(spacing: 12) {
                    Slider(value: activeMatch.overlayScaleFactor, in: Scoreboard.overlayScaleRange, step: 0.05)
                        .accessibilityLabel("Overlay scale")
                        .accessibilityValue(overlayScaleLabel)
                    Button("Reset overlay scale", systemImage: "arrow.counterclockwise") {
                        activeMatch.overlayScaleFactor.wrappedValue = 1
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .disabled(scoreboard.overlayScaleFactor == 1)
                }
            }

            OverlayPreview(scoreboard: scoreboard)
                .aspectRatio(Double(NearbyOverlayWire.canvasWidth) / Double(NearbyOverlayWire.canvasHeight),
                             contentMode: .fit)
                .background(Color(red: 0.10, green: 0.13, blue: 0.18))
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityHidden(true)
            Picker("Theme", selection: activeMatch.theme) {
                ForEach(Scoreboard.Theme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var overlayScaleLabel: String {
        scoreboard.overlayScaleFactor.formatted(.percent.precision(.fractionLength(0)))
    }

    private func teamCard(_ side: Scoreboard.Side) -> some View {
        let team = side == .home ? activeMatch.home : activeMatch.away
        let identity = switch sport {
        case .padel, .beachVolleyball: "pair"
        case .squash: "player"
        case .tableTennis, .badminton, .tennis, .pickleball: "player or pair"
        default: "team"
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(side.title).font(.headline)
                Spacer()
                ColorPicker("\(side.title) color", selection: team.jerseyColor, supportsOpacity: false)
                    .labelsHidden()
            }
            TextField("\(side.title) \(identity) name", text: team.name)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)

            switch sport {
            case .volleyball: volleyballScore(for: side)
            case .basketball, .basketball3x3: basketballPoints(for: side)
            case .americanFootball, .rugbyUnion: playPoints(for: side)
            case .baseball:
                if let baseball = scoreboard.baseballGame {
                    scoreAdjustments(for: side, value: baseball.position.runs(for: side), title: "Runs", unit: "run") {
                        activeMatch.wrappedValue.baseballGame?.adjustRuns($0, for: side)
                    }
                }
            case .cricket:
                LabeledContent("Runs/wickets", value: scoreboard.cricketMatch?.innings(for: side)?.score ?? "–")
                    .accessibilityIdentifier("cricket-\(side.rawValue)-total")
            case .handball, .floorball, .soccer, .futsal, .iceHockey, .fieldHockey, .netball:
                singleScore(for: side, goals: true)
            case .tableTennis, .badminton, .tennis, .squash, .padel, .beachVolleyball, .pickleball:
                if let match = scoreboard.rallyMatch {
                    rallyScore(for: side, match: match)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func rallyControls(_ match: RallyMatch) -> some View {
        let format = Binding {
            scoreboard.rallyMatch?.format ?? match.format
        } set: { format in
            activeMatch.wrappedValue.rallyMatch?.setFormat(format)
        }

        return HStack(spacing: 8) {
            if match.hasGames {
                Menu {
                    Picker("Match format", selection: format) {
                        ForEach(RallyMatch.Format.allCases.filter { $0.sport == sport }) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(match.format.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Match format")
                .accessibilityValue(match.format.title)
                .accessibilityIdentifier("racket-format")
                .disabled(!match.canChangeFormat)

                Spacer(minLength: 0)
            }

            if let status = match.status {
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("racket-status")
            }

            if !match.hasGames { Spacer(minLength: 0) }
            Button("Undo", systemImage: "arrow.uturn.backward") {
                activeMatch.wrappedValue.rallyMatch?.undo()
            }
            .buttonStyle(.bordered)
            .disabled(!match.canUndo)
        }
    }

    private func rallyScore(for side: Scoreboard.Side, match: RallyMatch) -> some View {
        let score = match[side]
        return VStack(alignment: .leading, spacing: 8) {
            if match.hasSets {
                LabeledContent("Sets", value: score.sets.formatted())
                    .accessibilityIdentifier("racket-\(side.rawValue)-sets")
            }
            if match.hasGames {
                LabeledContent("Games", value: score.games.formatted())
                    .accessibilityIdentifier("racket-\(side.rawValue)-games")
            }
            if sport == .pickleball {
                pickleballRally(for: side, match: match)
            } else {
                scoreButton(match.pointLabel(for: side), for: side, unit: "point", id: "add-\(side.rawValue)-racket-point") {
                    activeMatch.wrappedValue.rallyMatch?.recordRally(wonBy: side)
                }
                .disabled(match.winner != nil)
                serveButton(for: side, isServing: match.serving == side) {
                    activeMatch.wrappedValue.rallyMatch?.setServer(side)
                }
                .disabled(match.winner != nil)
            }
        }
    }

    private func pickleballRally(for side: Scoreboard.Side, match: RallyMatch) -> some View {
        let points = match.pointLabel(for: side)
        return VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Points", value: points)
                .accessibilityIdentifier("pickleball-\(side.rawValue)-points")
            if let server = match.serving {
                let isServing = server == side
                let servingLabel = match.pickleballServerNumber.map { "Server \($0)" } ?? "Serving"
                Label(isServing ? servingLabel : "Receiving", systemImage: isServing ? "circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isServing ? Color.accentColor : .secondary)
                    .accessibilityIdentifier("pickleball-\(side.rawValue)-service")

                Button {
                    activeMatch.wrappedValue.rallyMatch?.recordRally(wonBy: side)
                } label: {
                    Text("Won rally")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Record \(side.title.lowercased()) rally win")
                .accessibilityIdentifier("pickleball-\(side.rawValue)-rally")
            } else if match.winner == nil {
                serveButton(for: side, isServing: false) {
                    activeMatch.wrappedValue.rallyMatch?.setServer(side)
                }
            }
        }
    }

    private func basketballPoints(for side: Scoreboard.Side) -> some View {
        let points = scoreboard[side].points
        let team = side.title.lowercased()
        let threeOnThree = sport == .basketball3x3
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(points, format: .number)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .accessibilityLabel("\(side.title) points")
                    .accessibilityValue(Text(points, format: .number))
                Spacer()
                if !threeOnThree {
                    adjustmentButton("Remove \(team) point", icon: "minus") {
                        activeMatch.wrappedValue.adjustPoints(-1, for: side)
                    }
                    .disabled(points == 0)
                }
            }

            HStack(spacing: 6) {
                ForEach(1...(threeOnThree ? 2 : 3), id: \.self) { value in
                    Button {
                        if threeOnThree {
                            activeMatch.wrappedValue.awardThreeOnThreeBasket(value, for: side, at: .now)
                        } else {
                            activeMatch.wrappedValue.adjustPoints(value, for: side)
                        }
                    } label: {
                        Text("+\(value)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.tint, in: .rect(cornerRadius: 8))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(scoreboard.finishedThreeOnThreeByScore)
                    .accessibilityLabel("Add \(value) \(team) \(value == 1 ? "point" : "points")")
                    .accessibilityIdentifier("basketball-add-\(side.rawValue)-\(value)")
                }
            }
        }
    }

    private func playPoints(for side: Scoreboard.Side) -> some View {
        let points = scoreboard[side].points
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(points, format: .number)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .accessibilityLabel("\(side.title) points")
                    .accessibilityValue(Text(points, format: .number))
                Spacer()
                adjustmentButton("Remove \(side.title.lowercased()) point", icon: "minus") {
                    activeMatch.wrappedValue.adjustPoints(-1, for: side)
                }
                .disabled(points == 0)
            }

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                if sport == .rugbyUnion {
                    GridRow {
                        rugbyScoreButton(.tryScore, for: side)
                        rugbyScoreButton(.conversion, for: side)
                    }
                    GridRow {
                        rugbyScoreButton(.penaltyGoal, for: side)
                        rugbyScoreButton(.dropGoal, for: side)
                    }
                    rugbyScoreButton(.penaltyTry, for: side)
                        .gridCellColumns(2)
                } else {
                    GridRow {
                        footballScoreButton(.touchdown, for: side)
                        footballScoreButton(.fieldGoal, for: side)
                    }
                    GridRow {
                        footballScoreButton(.extraPoint, for: side)
                        footballScoreButton(.twoPointConversion, for: side)
                    }
                    footballScoreButton(.safety, for: side)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func footballScoreButton(_ play: Scoreboard.FootballGame.Score, for side: Scoreboard.Side) -> some View {
        playScoreButton(play.title, points: play.points, for: side, accessibilityTitle: play.accessibilityTitle,
                        id: "football-add-\(side.rawValue)-\(play.rawValue)")
    }

    private func rugbyScoreButton(_ play: Scoreboard.RugbyScore, for side: Scoreboard.Side) -> some View {
        playScoreButton(play.title, points: play.points, for: side, accessibilityTitle: play.title.lowercased(),
                        id: "rugby-add-\(side.rawValue)-\(play.rawValue)")
    }

    private func playScoreButton(_ title: String, points: Int, for side: Scoreboard.Side, accessibilityTitle: String,
                                 id: String) -> some View {
        Button {
            activeMatch.wrappedValue.adjustPoints(points, for: side)
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("\(title) +\(points)")
                VStack(spacing: 0) {
                    Text(title)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("+\(points)")
                }
            }
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .background(.tint, in: .rect(cornerRadius: 8))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(side.title.lowercased()) \(accessibilityTitle)")
        .accessibilityIdentifier(id)
    }

    private func singleScore(for side: Scoreboard.Side, goals: Bool) -> some View {
        scoreAdjustments(for: side, value: scoreboard[side].points, title: goals ? "Goals" : "Points",
                         unit: goals ? "goal" : "point") {
            activeMatch.wrappedValue.adjustPoints($0, for: side)
        }
    }

    private func scoreAdjustments(for side: Scoreboard.Side, value: Int, title: String, unit: String,
                                  adjust: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                adjustmentButton("Remove \(side.title.lowercased()) \(unit)", icon: "minus") {
                    adjust(-1)
                }
                .disabled(value == 0)

                scoreButton(value.formatted(), for: side, unit: unit, id: "add-\(side.rawValue)-\(unit)") {
                    adjust(1)
                }
            }
        }
    }

    private func volleyballScore(for side: Scoreboard.Side) -> some View {
        let sets = scoreboard[side].sets
        let isServing = scoreboard.serving == side
        return VStack(alignment: .leading, spacing: 12) {
            singleScore(for: side, goals: false)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sets").font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    adjustmentButton("Remove \(side.title.lowercased()) set", icon: "minus") {
                        activeMatch.wrappedValue.adjustSets(-1, for: side)
                    }
                    .disabled(sets == 0)
                    Text(sets, format: .number)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(side.title) sets")
                        .accessibilityValue(Text(sets, format: .number))
                    adjustmentButton("Add \(side.title.lowercased()) set", icon: "plus") {
                        activeMatch.wrappedValue.adjustSets(1, for: side)
                    }
                }
            }

            serveButton(for: side, isServing: isServing) {
                activeMatch.serving.wrappedValue = side
            }
        }
    }

    private func scoreButton(_ value: String, for side: Scoreboard.Side, unit: String, id: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Image(systemName: "plus").font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Add \(side.title.lowercased()) \(unit)")
        .accessibilityValue(value)
        .accessibilityIdentifier(id)
    }

    private func serveButton(for side: Scoreboard.Side, isServing: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(isServing ? "Serving" : "Set serve", systemImage: isServing ? "checkmark.circle.fill" : "circle")
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(isServing ? "\(side.title) serving" : "Set \(side.title.lowercased()) to serve")
        .accessibilityAddTraits(isServing ? .isSelected : [])
    }

    private func adjustmentButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .frame(minWidth: 34, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }

    private static func restoreScoreboards() -> [Scoreboard.Sport: Scoreboard] {
        Dictionary(uniqueKeysWithValues: Scoreboard.Sport.allCases.map { sport in
            let data = UserDefaults.standard.data(forKey: sport.storageKey)
            let stored = data.flatMap { try? JSONDecoder().decode(Scoreboard.self, from: $0) }
            return (sport, stored.flatMap { $0.sport == sport ? $0 : nil } ?? Scoreboard(sport: sport))
        })
    }
}

private struct CricketControls: View {
    @Binding var match: CricketMatch
    let homeName: String
    let awayName: String
    @State private var showingDeliveryEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.status)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("cricket-status")
                    Text(teamName(match.innings.batting))
                        .font(.headline)
                        .lineLimit(1)
                    HStack {
                        Text(match.innings.score)
                            .font(.title3.monospacedDigit().weight(.bold))
                            .accessibilityIdentifier("cricket-score")
                        Text("\(match.innings.overs) overs")
                            .monospacedDigit()
                            .accessibilityIdentifier("cricket-overs")
                    }
                }
                Spacer(minLength: 0)
                Button("Undo", systemImage: "arrow.uturn.backward") { match.undo() }
                    .buttonStyle(.bordered)
                    .disabled(!match.canUndo)
            }

            if match.canChooseFirstBatting {
                LabeledContent("Batting first") {
                    Picker("Batting first", selection: firstBatting) {
                        Text("Home").tag(Scoreboard.Side.home)
                        Text("Away").tag(Scoreboard.Side.away)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 176)
                    .accessibilityIdentifier("cricket-first-batting")
                }
            }

            if let target = match.target {
                Text("Target \(target)")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("cricket-target")
                if match.isChase, match.canRecord {
                    let needed = target - match.innings.runs
                    let balls = match.innings.ballsRemaining
                    Text("Need \(needed) \(needed == 1 ? "run" : "runs") from \(balls) \(balls == 1 ? "ball" : "balls")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if match.canStartChase {
                Button("Start chase") { match.startChase() }
                    .buttonStyle(.borderedProminent)
            } else if case let .won(side) = match.result {
                Text("\(teamName(side)) win")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("cricket-winner")
            } else if match.canRecord {
                deliveryButtons
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .sheet(isPresented: $showingDeliveryEditor) {
            CricketDeliveryEditor { delivery, runs, wicket in
                match.record(delivery, runs: runs, wicket: wicket)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var firstBatting: Binding<Scoreboard.Side> {
        Binding { match.firstBatting } set: { match.setFirstBatting($0) }
    }

    private var deliveryButtons: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    runButton(0)
                    runButton(1)
                    runButton(2)
                }
                GridRow {
                    runButton(3)
                    runButton(4)
                    runButton(6)
                }
                GridRow {
                    entryButton("Wicket", id: "cricket-wicket") { match.record(.legal, wicket: true) }
                    entryButton("Wide", id: "cricket-wide") { match.record(.wide) }
                    entryButton("No ball", id: "cricket-no-ball") { match.record(.noBall) }
                }
            }
            Button("More delivery options", systemImage: "ellipsis.circle") { showingDeliveryEditor = true }
                .font(.subheadline)
                .buttonStyle(.bordered)
        }
    }

    private func runButton(_ runs: Int) -> some View {
        entryButton(runs == 0 ? "Dot" : String(runs), id: "cricket-runs-\(runs)") {
            match.record(.legal, runs: runs)
        }
        .accessibilityLabel(runs == 0 ? "Dot ball" : "\(runs) \(runs == 1 ? "run" : "runs")")
    }

    private func entryButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .background(.tint, in: .rect(cornerRadius: 8))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func teamName(_ side: Scoreboard.Side) -> String {
        let name = side == .home ? homeName : awayName
        return name.isEmpty ? side.title : name
    }
}

private struct CricketDeliveryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var delivery = CricketMatch.Delivery.legal
    @State private var runs = 0
    @State private var wicket = false
    let record: (CricketMatch.Delivery, Int, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Delivery", selection: $delivery) {
                    ForEach(CricketMatch.Delivery.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .accessibilityIdentifier("cricket-delivery-type")

                Stepper(value: $runs, in: CricketMatch.entryRunRange) {
                    LabeledContent(delivery.penaltyRuns == 0 ? "Runs" : "Additional runs", value: runs.formatted())
                }
                .accessibilityIdentifier("cricket-delivery-runs")

                Toggle("Wicket", isOn: $wicket)

                if delivery.penaltyRuns > 0 {
                    LabeledContent("Runs credited", value: (runs + delivery.penaltyRuns).formatted())
                }
            }
            .navigationTitle("Record delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        record(delivery, runs, wicket)
                        dismiss()
                    }
                    .disabled(delivery == .noDelivery && runs == 0 && !wicket)
                }
            }
        }
    }
}

private struct BaseballControls: View {
    @Binding var game: BaseballGame

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                halfButton("Previous half-inning", icon: "chevron.left") { game.previousHalf() }
                    .disabled(!game.canGoBack)
                Text(game.position.inningLabel)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityIdentifier("baseball-inning")
                halfButton("Next half-inning", icon: "chevron.right") { game.nextHalf() }
                Spacer(minLength: 0)
                Button("Undo", systemImage: "arrow.uturn.backward") { game.undo() }
                    .buttonStyle(.bordered)
                    .disabled(!game.canUndo)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    countControls
                    bases
                }
                VStack(spacing: 8) {
                    countControls
                    bases
                }
            }

            Button("New batter") { game.newBatter() }
                .buttonStyle(.bordered)
                .disabled(game.position.balls == 0 && game.position.strikes == 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private var countControls: some View {
        VStack(spacing: 6) {
            ForEach(BaseballGame.Count.allCases) { kind in
                let value = Binding {
                    game.position.count(kind)
                } set: { count in
                    game.setCount(count, for: kind)
                }
                HStack {
                    Text(kind.title).font(.subheadline)
                    Spacer(minLength: 6)
                    Text(value.wrappedValue, format: .number)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                    Stepper(kind.title, value: value, in: kind.range)
                        .labelsHidden()
                        .accessibilityValue(value.wrappedValue.formatted())
                        .accessibilityIdentifier("baseball-\(kind.rawValue)")
                }
            }
        }
    }

    private var bases: some View {
        VStack(spacing: -4) {
            baseButton(.second)
            HStack(spacing: 22) {
                baseButton(.third)
                baseButton(.first)
            }
        }
    }

    private func baseButton(_ base: BaseballGame.Base) -> some View {
        let occupied = game.position.occupiedBases.contains(base)
        return Button {
            game.toggleBase(base)
        } label: {
            Image(systemName: occupied ? "diamond.fill" : "diamond")
                .font(.title2.weight(.semibold))
                .foregroundStyle(occupied ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(base.title)
        .accessibilityValue(occupied ? "Occupied" : "Empty")
        .accessibilityAddTraits(occupied ? .isSelected : [])
        .accessibilityIdentifier("baseball-base-\(base.rawValue)")
    }

    private func halfButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(title)
    }
}

private struct FootballSituationControls: View {
    @Binding var game: Scoreboard.FootballGame
    @State private var editingDistance = false

    var body: some View {
        VStack(spacing: 10) {
            LabeledContent("Possession") {
                Picker("Possession", selection: $game.possession) {
                    Text("None").tag(Optional<Scoreboard.Side>.none)
                    Text("Home").tag(Optional(Scoreboard.Side.home))
                    Text("Away").tag(Optional(Scoreboard.Side.away))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 236)
                .accessibilityIdentifier("football-possession")
            }

            LabeledContent("Down") {
                Picker("Down", selection: $game.down) {
                    ForEach(Scoreboard.FootballGame.Down.allCases) { down in
                        Text(down.title).tag(down)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 236)
                .accessibilityIdentifier("football-down")
            }

            HStack(spacing: 8) {
                Button("1st & 10") { game.firstAndTen() }
                    .buttonStyle(.bordered)
                    .disabled(game.down == .first && game.yardsToGo == 10 && !game.goalToGo)

                Spacer(minLength: 0)

                Button(game.goalToGo ? "Goal to go" : "\(game.yardsToGo) yd") {
                    editingDistance = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Set distance")
                .accessibilityValue(game.goalToGo ? "Goal to go" : "\(game.yardsToGo) yards")
                .accessibilityIdentifier("football-distance")

                Stepper("Yards to go", value: $game.yardsToGo, in: Scoreboard.FootballGame.yardRange)
                    .labelsHidden()
                    .disabled(game.goalToGo)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .sheet(isPresented: $editingDistance) {
            FootballDistanceEditor(yards: game.yardsToGo, goalToGo: game.goalToGo) { yards, goalToGo in
                game.yardsToGo = yards
                game.goalToGo = goalToGo
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct FootballDistanceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var yards: Int
    @State var goalToGo: Bool
    let save: (Int, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Distance type", selection: $goalToGo) {
                    Text("Yards").tag(false)
                    Text("Goal to go").tag(true)
                }
                .pickerStyle(.segmented)
                if !goalToGo {
                    Picker("Yards to go", selection: $yards) {
                        ForEach(Scoreboard.FootballGame.yardRange, id: \.self) { value in
                            Text(value.formatted()).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle("Distance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        save(yards, goalToGo)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GameClockControls: View {
    let sport: Scoreboard.Sport
    @Binding var game: Scoreboard.TimedGame
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let period = sport.period(game.period) {
            controls(for: period)
        }
    }

    private func controls(for period: Scoreboard.GamePeriod) -> some View {
        let clock = game.clock(in: period)
        return TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let running = clock.isRunning(at: context.date)
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))

            layout {
                HStack(spacing: 4) {
                    periodButton("Previous period", icon: "chevron.left", change: -1)
                        .disabled(running || game.period == 1)
                    Text(period.label)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(period.accessibilityLabel)
                        .accessibilityIdentifier("game-period")
                    periodButton("Next period", icon: "chevron.right", change: 1)
                        .disabled(running || game.period == Int.max || sport.period(game.period + 1) == nil)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                GameClockButtons(game: $game, period: period, date: context.date)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func periodButton(_ title: String, icon: String, change: Int) -> some View {
        Button {
            game.changePeriod(by: change, for: sport, at: .now)
        } label: {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(title)
    }
}

private struct ThreeOnThreeControls: View {
    @Binding var match: Scoreboard
    @Binding var game: Scoreboard.TimedGame

    var body: some View {
        if let period = match.sport.period(1) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                VStack(spacing: 8) {
                    HStack {
                        Text(match.threeOnThreeStatus(at: context.date))
                            .font(.headline)
                            .accessibilityIdentifier("3x3-status")
                        Spacer()
                        if match.threeOnThree?.overtimeTarget == nil {
                            GameClockButtons(game: $game, period: period, date: context.date)
                                .disabled(match.finishedThreeOnThreeByScore)
                        }
                    }

                    HStack {
                        if match.canStartThreeOnThreeOvertime(at: context.date) {
                            Button("Start overtime") { match.startThreeOnThreeOvertime(at: .now) }
                                .buttonStyle(.borderedProminent)
                        } else if let target = match.threeOnThree?.overtimeTarget {
                            Text("First to \(target)").font(.subheadline)
                        }
                        Spacer()
                        Button("Undo", systemImage: "arrow.uturn.backward") { match.undoThreeOnThreeChange() }
                            .buttonStyle(.bordered)
                            .disabled(match.threeOnThree?.canUndo != true)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
    }
}

private struct GameClockButtons: View {
    @Binding var game: Scoreboard.TimedGame
    let period: Scoreboard.GamePeriod
    let date: Date
    @State private var showingClockEditor = false

    var body: some View {
        let clock = game.clock(in: period)
        let running = clock.isRunning(at: date)

        HStack(spacing: 6) {
            Button {
                showingClockEditor = true
            } label: {
                Text(clock.label(at: date))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 64, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(running)
            .accessibilityLabel("Set game clock")
            .accessibilityValue(clock.label(at: date))
            .accessibilityIdentifier("game-clock")

            Button {
                game.toggleClock(at: .now, in: period)
            } label: {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(!clock.canRun(at: date))
            .accessibilityLabel(running ? "Pause clock" : "Start clock")
            .accessibilityIdentifier("game-clock-toggle")
        }
        .sheet(isPresented: $showingClockEditor) {
            GameClockEditor(tenths: clock.displayTenths(at: .now), period: period) { totalSeconds in
                game.setClock(seconds: totalSeconds, in: period)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct GameClockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var fraction: Int
    let period: Scoreboard.GamePeriod
    let save: (TimeInterval) -> Void

    private var enteredSeconds: TimeInterval {
        Double(minutes * 60 + seconds) + Double(fraction) / 10
    }

    init(tenths: Int, period: Scoreboard.GamePeriod, save: @escaping (TimeInterval) -> Void) {
        _minutes = State(initialValue: tenths / 600)
        _seconds = State(initialValue: (tenths / 10) % 60)
        _fraction = State(initialValue: tenths % 10)
        self.period = period
        self.save = save
    }

    var body: some View {
        NavigationStack {
            HStack {
                timePicker("Minutes", selection: $minutes, values: 0...Int(period.maximumClockSeconds / 60))
                timePicker("Seconds", selection: $seconds, values: 0...59)
                if period.showsTenths {
                    timePicker("Tenths", selection: $fraction, values: 0...9)
                }
            }
            .padding()
            .navigationTitle("Set game clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        save(enteredSeconds)
                        dismiss()
                    }
                    .disabled(enteredSeconds > period.maximumClockSeconds)
                }
            }
        }
    }

    private func timePicker(_ title: String, selection: Binding<Int>, values: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.subheadline)
                .accessibilityHidden(true)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text($0.formatted(.number.grouping(.never))).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 144)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension NearbyOverlaySender.ConnectionState {
    var indicator: (title: LocalizedStringKey, symbol: String, color: Color) {
        switch self {
        case .unpaired: ("Unpaired", "dot.radiowaves.left.and.right", .secondary)
        case .connecting: ("Pairing…", "ellipsis.circle", .orange)
        case .checking: ("Checking…", "ellipsis.circle", .orange)
        case .paired: ("Paired", "checkmark.circle.fill", .green)
        case .reconnecting: ("Reconnecting…", "arrow.triangle.2.circlepath", .orange)
        case .lost: ("Connection lost", "exclamationmark.triangle.fill", .red)
        }
    }
}

private extension Scoreboard.Team {
    var jerseyColor: Color {
        get {
            Color(
                red: Double((rgb >> 16) & 255) / 255,
                green: Double((rgb >> 8) & 255) / 255,
                blue: Double(rgb & 255) / 255
            )
        }
        set {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            guard UIColor(newValue).getRed(&red, green: &green, blue: &blue, alpha: nil) else { return }

            func channel(_ value: CGFloat) -> UInt32 {
                UInt32((min(1, max(0, value)) * 255).rounded())
            }

            rgb = (channel(red) << 16) | (channel(green) << 8) | channel(blue)
        }
    }
}
