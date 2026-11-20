# Tubeist Scorer

Tubeist Scorer is a standalone SwiftUI app for iPhone and iPad. It lets a scorekeeper enter teams, choose a scoreboard theme, and score twenty-one sports, including volleyball, basketball, tennis, and ice hockey. The live preview uses the same local web overlay that will be sent to Tubeist.

Open **TubeistScorer.xcodeproj** and run the **TubeistScorer** scheme on an iOS 18 or later simulator. To run on a physical device, select your development team in the target's Signing & Capabilities settings.

## Sports

Choose the **Sport** above the preview. Scorer saves a match for each sport
and shows the selected match on the connected overlay.

- **Volleyball** tracks points, sets and serve.
- **Basketball** has +1, +2 and +3 scoring, four 10-minute quarters and
  5-minute overtimes. The clock counts down.
- **Handball** uses an elapsed clock for two 30-minute halves and optional
  overtime halves of five minutes each.
- **Floorball** has three 20-minute periods and an optional 10-minute
  overtime. The clock starts at 0:00 each period.
- **Soccer** counts up from 0:00 and 45:00 for the two halves, and from
  90:00 and 105:00 for optional extra time. Leave the clock running to
  include stoppage time.
- **Table tennis** plays 11-point, win-by-two games with best-of-3,
  best-of-5, or best-of-7 matches. The default is best of 5.
- **Badminton** supports best-of-3 matches with either 21-point games
  (capped at 30) or 15-point games (capped at 21).
- **Tennis** supports best of 3 or 5 full sets, with advantage scoring and a
  seven-point, win-by-two tiebreak at 6–6 in each set.
- **Squash** tracks 11-point, win-by-two games in best-of-3 or best-of-5
  matches. The rally winner serves next.
- **Futsal** counts down two 20-minute halves and two optional five-minute
  extra-time halves.
- **Padel** uses best-of-3 sets with a tiebreak at 6–6. Choose Advantage,
  Golden Point at the first deuce, or Star Point after two advantages
  have been cancelled. The default is Star Point.
- **Ice hockey** counts down three 20-minute periods. Overtime starts at
  5:00, and the clock can be adjusted for other competition formats.
- **Beach volleyball** advances through sets to 21 points and a deciding set
  to 15. Each set requires a two-point lead, and two sets win the match.
  Choose the opening serving side at the start of each set.
- **3×3 basketball** has +1 and +2 baskets and a single 10-minute game clock.
  Reaching 21 ends regulation early. When the clock expires tied, tap
  **Start overtime**. Overtime is untimed and ends when one side adds two
  points. **Undo** reverses the last basket or the start of overtime.
- **American football** has scoring buttons for touchdowns, field goals,
  extra points, two-point conversions, and safeties. The clock starts at
  15:00 per quarter and 10:00 in overtime. Set the clock to match your
  competition. Choose possession, down, and distance manually. Tap the
  distance for **Goal to go**, or use **1st & 10** to reset the down and distance.
- **Baseball** tracks runs, inning halves, balls, strikes, outs, and occupied
  bases. Tap a base to place or remove a runner. Use **New batter** to clear
  the balls and strikes after a plate appearance. The third out advances the
  half-inning and clears the count and bases. **Undo** restores the previous
  score and field state.
- **T20 cricket** tracks runs, wickets, overs and the chase target. Choose
  who bats first and record each delivery. **Wide** and **No ball** add
  a run without using a ball of the over. Use **More delivery options**
  to combine runs and a wicket, or record an event without a delivery.
  The first innings ends at 20 overs or 10 wickets. Tap **Start chase**
  to switch sides. **Undo** restores the previous delivery or innings.
- **Field hockey** tracks goals and counts down four 15-minute quarters
  for outdoor 11-a-side matches.
- **Rugby union** has buttons for tries, conversions, penalty goals,
  drop goals, and penalty tries. For 15-a-side matches, the clock counts up
  from 0:00 and 40:00. Pause the clock when the referee ends the half.
- **Netball** tracks goals and counts down four 15-minute quarters.
- **Pickleball** supports singles and doubles in best-of-3 matches to 11,
  win by two. Choose the opening serve, then tap **Won rally** for the side
  that won each rally. Under side-out scoring, a win by the serving side
  adds a point. A win by the receiving side advances the server. The overlay
  shows the serving side and the current server number in doubles.

In racket sports, choose the match format before scoring and tap
**Set serve** for the opening server. Scorer advances games,
sets, and the serving side as points are scored. **Undo** restores the
previous score and server, including across a game or set boundary.

In timed sports, use the arrows to change periods while the clock is stopped.
Start and pause the clock with the play and pause button, and tap the clock
while it is stopped to correct its time. The clock uses the time set on each
device.

## Overlay

The self-contained overlay is in [TubeistScorer/Overlay](TubeistScorer/Overlay). The preview loads its entry page in WebKit and dispatches a DOM event named **overlay:update** with the current match as its detail. The page uses that data to update the graphic. All of the scoring logic and choices live in this app and the overlay package.

Tap the percentage beside **Overlay preview** to adjust the overlay from 25% to
200%. Changes apply to the local preview and to the connected Tubeist overlay.
The scale is saved with the match.

## Connect to Tubeist

1. In Tubeist, open **Settings → Overlays → Nearby Overlay**, or touch and hold **Overlays** on the camera screen and choose **Nearby Overlay**. Tap **Start receiving**.
2. On the scorer device, tap **Connect to Tubeist** in the toolbar. Enter the six-digit code from Tubeist, select the nearby receiver, and accept the system Bluetooth prompt if it appears.
3. After the connection reports **Connected to Tubeist**, tap **Done** on both devices. Changes to teams, theme, or the match update the overlay as you score.

The toolbar shows whether Scorer is unpaired, paired, or reconnecting.
If a connection ends unexpectedly, it shows **Connection lost**. Scorer
periodically checks the pairing while open. Tap the indicator to open the
Bluetooth controls.

Scorer sends the self-contained overlay package when Tubeist needs it. When a
paired scorer goes out of range, it keeps waiting for Tubeist and sends the
latest match state when it reconnects. Keep the receiving session running in
Tubeist and return Scorer to the foreground if the scoring phone goes to sleep.
If Tubeist asks for a fresh pairing, use **New pairing code** on the receiver
and enter that code in Scorer. Both apps use their Bluetooth permissions for
the direct connection. Scoring and the local preview work offline.

## License

Tubeist Scorer is licensed under the [MIT License](LICENSE).

The overlay styles and volleyball icons are adapted from the adjacent Scoreboard project. The [original MIT notice](TubeistScorer/Overlay/LICENSE.txt) ships with them.
