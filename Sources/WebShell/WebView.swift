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
        // Kill the white flash / 1px border
        webView.setValue(false, forKey: "drawsBackground")
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
            <html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:-apple-system,sans-serif;background:#fefefe;color:#333;">
            <div style="text-align:center;max-width:360px">
            <div style="font-size:48px;opacity:0.2;margin-bottom:16px">⚠️</div>
            <h2 style="font-weight:500;font-size:18px;margin:0 0 8px">Connection Failed</h2>
            <p style="font-size:13px;color:#666;margin:0 0 24px">\(error.localizedDescription)</p>
            <p style="font-size:12px;color:#999">Check if the server is running and the URL is correct.</p>
            </div></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
