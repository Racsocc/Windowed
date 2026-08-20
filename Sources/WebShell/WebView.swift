import SwiftUI
import WebKit
import AppKit

struct WebView: NSViewRepresentable {
    let urlString: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = validatedURL(from: urlString) else {
            showInvalidURLError(in: webView, value: urlString)
            return
        }
        if webView.url?.absoluteString != urlString {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func validatedURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func showInvalidURLError(in webView: WKWebView, value: String) {
        let escapedValue = value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let html = """
        <html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:-apple-system,sans-serif;background:#fefefe;color:#333;">
        <div style="text-align:center;max-width:420px">
        <div style="font-size:48px;opacity:0.2;margin-bottom:16px">!</div>
        <h2 style="font-weight:500;font-size:18px;margin:0 0 8px">Invalid URL</h2>
        <p style="font-size:13px;color:#666;margin:0 0 16px">The saved address could not be opened.</p>
        <p style="font-size:12px;color:#999;margin:0 0 20px"><code>\(escapedValue)</code></p>
        <p style="font-size:12px;color:#999">Use a full http:// or https:// URL.</p>
        </div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty,
               let window = webView.window {
                window.title = title
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !shouldIgnore(error) else { return }
            showError(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !shouldIgnore(error) else { return }
            showError(webView, error: error)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.shouldPerformDownload,
               let url = navigationAction.request.url,
               openExternally(url) {
                decisionHandler(.cancel)
                return
            }

            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               openExternally(url) {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if !navigationResponse.canShowMIMEType,
               let url = navigationResponse.response.url,
               openExternally(url) {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentAlert(on: webView, message: message, buttons: ["OK"]) { _ in
                completionHandler()
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            presentAlert(on: webView, message: message, buttons: ["Confirm", "Cancel"]) { response in
                completionHandler(response == .alertFirstButtonReturn)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let inputField = NSTextField(string: defaultText ?? "")
            inputField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)

            presentAlert(
                on: webView,
                message: prompt,
                buttons: ["OK", "Cancel"],
                accessoryView: inputField
            ) { response in
                completionHandler(response == .alertFirstButtonReturn ? inputField.stringValue : nil)
            }
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.message = parameters.allowsMultipleSelection ? "Choose files to upload" : "Choose a file to upload"

            if let window = webView.window {
                panel.beginSheetModal(for: window) { response in
                    completionHandler(response == .OK ? panel.urls : nil)
                }
            } else {
                completionHandler(panel.runModal() == .OK ? panel.urls : nil)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                _ = openExternally(url)
            }
            return nil
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

        private func presentAlert(
            on webView: WKWebView,
            message: String,
            buttons: [String],
            accessoryView: NSView? = nil,
            completion: @escaping (NSApplication.ModalResponse) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message.isEmpty ? "JavaScript Dialog" : message
            alert.informativeText = pageTitle(for: webView)
            alert.alertStyle = .informational
            buttons.forEach { alert.addButton(withTitle: $0) }
            alert.accessoryView = accessoryView

            if let window = webView.window {
                alert.beginSheetModal(for: window, completionHandler: completion)
            } else {
                completion(alert.runModal())
            }
        }

        private func pageTitle(for webView: WKWebView) -> String {
            if let host = webView.url?.host, !host.isEmpty {
                return host
            }
            return "This page says"
        }

        private func openExternally(_ url: URL) -> Bool {
            NSWorkspace.shared.open(url)
        }

        private func shouldIgnore(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
        }
    }
}
