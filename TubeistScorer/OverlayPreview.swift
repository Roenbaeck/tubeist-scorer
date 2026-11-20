import OSLog
import SwiftUI
import WebKit

struct OverlayPreview: UIViewRepresentable {
    var scoreboard: Scoreboard

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> Canvas {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: Canvas.overlaySize),
            configuration: configuration
        )
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        context.coordinator.load(in: webView)
        return Canvas(webView: webView)
    }

    func updateUIView(_ canvas: Canvas, context: Context) {
        context.coordinator.update(scoreboard, in: canvas.webView)
    }

    final class Canvas: UIView {
        static let overlaySize = CGSize(width: NearbyOverlayWire.canvasWidth, height: NearbyOverlayWire.canvasHeight)
        let webView: WKWebView

        init(webView: WKWebView) {
            self.webView = webView
            super.init(frame: .zero)
            clipsToBounds = true
            addSubview(webView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("The overlay canvas is created in code")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard !bounds.isEmpty else { return }
            let scale = min(bounds.width / Self.overlaySize.width, bounds.height / Self.overlaySize.height)
            webView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let logger = Logger(subsystem: "com.subside.TubeistScorer", category: "OverlayPreview")
        private var navigation: WKNavigation?
        private var isReady = false
        private var latestScoreboard: Scoreboard?
        private var submittedScoreboard: Scoreboard?

        func load(in webView: WKWebView) {
            isReady = false
            submittedScoreboard = nil
            guard let entryPage = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Overlay") else {
                logger.error("The overlay entry page is missing from the app bundle")
                return
            }
            navigation = webView.loadFileURL(entryPage, allowingReadAccessTo: entryPage.deletingLastPathComponent())
        }

        func update(_ scoreboard: Scoreboard, in webView: WKWebView) {
            latestScoreboard = scoreboard
            renderIfNeeded(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard self.navigation === navigation else { return }
            isReady = true
            renderIfNeeded(in: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            load(in: webView)
        }

        private func renderIfNeeded(in webView: WKWebView) {
            guard isReady, let latestScoreboard, latestScoreboard != submittedScoreboard,
                  let data = try? latestScoreboard.overlayUpdateData() else { return }
            submittedScoreboard = latestScoreboard

            webView.callAsyncJavaScript(
                "return window.dispatchEvent(new CustomEvent('overlay:update', {detail: JSON.parse(payload)}));",
                arguments: ["payload": String(decoding: data, as: UTF8.self)],
                in: nil,
                in: .page
            ) { [weak self] result in
                if case let .failure(error) = result {
                    self?.logger.error("Could not update the overlay preview: \(error.localizedDescription)")
                    if self?.submittedScoreboard == latestScoreboard {
                        self?.submittedScoreboard = nil
                    }
                }
            }
        }
    }
}
