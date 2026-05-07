import Foundation
import Combine

/// Starts a local service in the background and polls until it's ready.
final class ServiceStarter: ObservableObject {
    enum Status: Equatable {
        case idle
        case starting
        case ready
        case failed(String)
    }

    @Published var status: Status = .idle

    private var pollTimer: Timer?

    /// Returns true if the URL points to a local address.
    static func isLocal(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.hasPrefix("http://127.0.0.1")
            || lower.hasPrefix("http://localhost")
            || lower.hasPrefix("https://127.0.0.1")
            || lower.hasPrefix("https://localhost")
    }

    /// Start a service by running the given shell command, then poll `healthURL` until it responds.
    /// - Parameters:
    ///   - command: Shell command to run (e.g. "~/hermes-webui/ctl.sh start").
    ///   - healthURL: URL to poll for readiness. Defaults to the saved URL.
    ///   - timeout: Max seconds to wait. Default 15.
    func start(command: String, healthURL: String, timeout: TimeInterval = 15) {
        // Already healthy? Skip.
        if checkHealth(healthURL) {
            status = .ready
            return
        }

        status = .starting
        launch(command: command)

        let deadline = Date().addingTimeInterval(timeout)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }

            if self.checkHealth(healthURL) {
                timer.invalidate()
                DispatchQueue.main.async { self.status = .ready }
            } else if Date() > deadline {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.status = .failed("Service didn't respond in time.")
                }
            }
        }
    }

    func reset() {
        pollTimer?.invalidate()
        pollTimer = nil
        status = .idle
    }

    // MARK: - Private

    private func launch(command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", command]

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(env["PATH"] ?? "/usr/bin")"
            proc.environment = env

            // Capture output for debugging.
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if proc.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        // Don't override if health check already passed.
                        if self.status == .starting {
                            self.status = .failed("Exit code \(proc.terminationStatus): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .failed("Failed to run: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkHealth(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
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
