import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let youtubeId: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator

        loadVideo(in: webView)
        context.coordinator.loadedId = youtubeId
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedId != youtubeId else { return }
        loadVideo(in: webView)
        context.coordinator.loadedId = youtubeId
    }

    private func loadVideo(in webView: WKWebView) {
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; background: #000; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
        <iframe
          src="https://www.youtube.com/embed/\(youtubeId)?playsinline=1&rel=0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var loadedId: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            .allow
        }
    }
}
