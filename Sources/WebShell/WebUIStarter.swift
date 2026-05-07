import Foundation
import Combine

/// Starts the Hermes WebUI service in the background and waits until it's ready.
final class WebUIStarter: ObservableObject {
    enum Status: Equatable {
        case idle
        case starting
        case ready
        case failed(String)
    }

    @Published var status: Status = .idle

    private let webuiDir: String
    private let healthURL: String
    private var pollTimer: Timer?

    init(webuiDir: String = "\(NSHomeDirectory())/hermes-webui",
         healthURL: String = "http://127.0.0.1:8787") {
        self.webuiDir = webuiDir
        self.healthURL = healthURL
    }

    /// Returns true if the URL looks like a local Hermes WebUI instance.
    static func isLocalWebUI(_ url: String) -> Bool {
        let lower = url.lowercased()
        return (lower.contains("127.0.0.1:8787") || lower.contains("localhost:8787"))
    }

    /// Launch ctl.sh start if the service isn't already responding.
    func startIfNeeded() {
        // Already healthy? Skip.
        if checkHealth() {
            status = .ready
            return
        }

        status = .starting
        launchScript()

        // Poll until ready or timeout.
        let deadline = Date().addingTimeInterval(15)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }

            if self.checkHealth() {
                timer.invalidate()
                DispatchQueue.main.async { self.status = .ready }
            } else if Date() > deadline {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.status = .failed("WebUI didn't respond in time. Check ~/hermes-webui/logs.")
                }
            }
        }
    }

    // MARK: - Private

    private func launchScript() {
        let ctlPath = (webuiDir as NSString).appendingPathComponent("ctl.sh")
        guard FileManager.default.fileExists(atPath: ctlPath) else {
            status = .failed("ctl.sh not found at \(ctlPath)")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = [ctlPath, "start"]
            proc.currentDirectoryURL = URL(fileURLWithPath: self.webuiDir)

            // Inherit PATH so python3 etc. are found.
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(env["PATH"] ?? "/usr/bin")"
            proc.environment = env

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.status = .failed("Failed to launch: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkHealth() -> Bool {
        guard let url = URL(string: healthURL) else { return false }
        var healthy = false
        let sem = DispatchSemaphore(value: 0)

        var req = URLRequest(url: url)
        req.timeoutInterval = 2

        URLSession.shared.dataTask(with: req) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                healthy = true
            }
            sem.signal()
        }.resume()

        _ = sem.wait(timeout: .now() + 3)
        return healthy
    }
}
