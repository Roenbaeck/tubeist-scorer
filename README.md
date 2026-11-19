# Tubeist Scorer

Tubeist Scorer is a standalone SwiftUI app for iPhone and iPad. It lets a scorekeeper enter teams, choose a scoreboard theme, and adjust points, sets, and the serving side. The live preview uses the same local web overlay that will be sent to Tubeist.

Open **TubeistScorer.xcodeproj** and run the **TubeistScorer** scheme on an iOS 18 or later simulator. To run on a physical device, select your development team in the target's Signing & Capabilities settings.

## Overlay

The self-contained overlay is in [TubeistScorer/Overlay](TubeistScorer/Overlay). The preview loads its entry page in WebKit and dispatches a DOM event named **overlay:update** with the current match as its detail. The page uses that data to update the graphic. All of the scoring logic and choices live in this app and the overlay package.

Device pairing, package transfer, and Tubeist's local overlay source are pending. The current app supports local scoring and preview. Its controls and assets work offline.

The overlay styles and volleyball icons are adapted from the adjacent Scoreboard project. The [original MIT notice](TubeistScorer/Overlay/LICENSE.txt) ships with them.
