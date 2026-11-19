import SwiftUI
import UIKit

struct ScoreboardView: View {
    private static let storageKey = "scoreboard"
    @State private var scoreboard = ScoreboardView.restoreScoreboard()
    @State private var isConfirmingReset = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overlayPreview
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) {
                            teamCard(.home)
                            teamCard(.away)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            teamCard(.home)
                            teamCard(.away)
                        }
                    }
                }
                .frame(maxWidth: 680)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tubeist Scorer")
            .toolbar {
                Button("Reset") { isConfirmingReset = true }
            }
            .confirmationDialog("Reset scores", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Reset points", role: .destructive) { scoreboard.resetPoints() }
                Button("Reset match", role: .destructive) { scoreboard.resetMatch() }
            }
        }
        .onChange(of: scoreboard) { _, updated in
            if let data = try? JSONEncoder().encode(updated) {
                UserDefaults.standard.set(data, forKey: Self.storageKey)
            }
        }
    }

    private var overlayPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overlay preview").font(.headline)
            OverlayPreview(scoreboard: scoreboard)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(Color(red: 0.10, green: 0.13, blue: 0.18))
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityHidden(true)
            Picker("Theme", selection: $scoreboard.theme) {
                ForEach(Scoreboard.Theme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func teamCard(_ side: Scoreboard.Side) -> some View {
        let team = side == .home ? $scoreboard.home : $scoreboard.away
        let points = team.wrappedValue.points
        let sets = team.wrappedValue.sets
        let isServing = scoreboard.serving == side

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(side.title).font(.headline)
                Spacer()
                ColorPicker("\(side.title) jersey color", selection: team.jerseyColor, supportsOpacity: false)
                    .labelsHidden()
            }
            TextField("\(side.title) team name", text: team.name)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)

            Text("Points").font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                adjustmentButton("Remove \(side.title.lowercased()) point", icon: "minus") {
                    scoreboard.adjustPoints(-1, for: side)
                }
                .disabled(points == 0)

                Button {
                    scoreboard.adjustPoints(1, for: side)
                } label: {
                    HStack(spacing: 6) {
                        Text(points, format: .number)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Image(systemName: "plus").font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add \(side.title.lowercased()) point")
                .accessibilityValue(Text(points, format: .number))
                .accessibilityIdentifier("add-\(side.rawValue)-point")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sets").font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    adjustmentButton("Remove \(side.title.lowercased()) set", icon: "minus") {
                        scoreboard.adjustSets(-1, for: side)
                    }
                    .disabled(sets == 0)
                    Text(sets, format: .number)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(side.title) sets")
                        .accessibilityValue(Text(sets, format: .number))
                    adjustmentButton("Add \(side.title.lowercased()) set", icon: "plus") {
                        scoreboard.adjustSets(1, for: side)
                    }
                }
            }

            Button {
                scoreboard.serving = side
            } label: {
                Label(isServing ? "Serving" : "Set serve", systemImage: isServing ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(isServing ? "\(side.title) serving" : "Set \(side.title.lowercased()) to serve")
            .accessibilityAddTraits(isServing ? .isSelected : [])
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
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

    private static func restoreScoreboard() -> Scoreboard {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let scoreboard = try? JSONDecoder().decode(Scoreboard.self, from: data) {
            return scoreboard
        }
        return Scoreboard()
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
