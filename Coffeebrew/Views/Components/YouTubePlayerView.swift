import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let youtubeId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
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
          allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }
}
