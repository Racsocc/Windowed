import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let urlString: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = true
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if webView.url?.absoluteString != urlString {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty,
               let window = webView.window {
                window.title = title
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showError(webView, error: error)
        }

        private func showError(_ webView: WKWebView, error: Error) {
            let html = """
            <html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:-apple-system,sans-serif;background:#1a1a1a;color:#ccc;">
            <div style="text-align:center">
            <h2>⚠️ Connection Failed</h2>
            <p>\(error.localizedDescription)</p>
            <p style="color:#666">Check if the server is running and the URL is correct.</p>
            </div></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
