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
    private let stateQueue = DispatchQueue(label: "Windowed.ServiceStarter")
    private var currentProcess: Process?
    private var launchToken: UUID = UUID()
    private var activeStopCommand: String?

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
    func start(command: String, healthURL: String, stopCommand: String? = nil, timeout: TimeInterval = 15) {
        let token = UUID()
        setLaunchToken(token)

        // Already healthy? Skip.
        if checkHealth(healthURL) {
            terminateRunningProcess()
            clearActiveStopCommand()
            status = .ready
            return
        }

        terminateRunningProcess()
        status = .starting
        launch(command: command, stopCommand: stopCommand, token: token)

        let deadline = Date().addingTimeInterval(timeout)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard self.isCurrentToken(token) else {
                timer.invalidate()
                return
            }

            if self.checkHealth(healthURL) {
                timer.invalidate()
                DispatchQueue.main.async {
                    if self.isCurrentToken(token) {
                        self.status = .ready
                    }
                }
            } else if Date() > deadline {
                timer.invalidate()
                DispatchQueue.main.async {
                    if self.isCurrentToken(token) {
                        self.status = .failed("Service didn't respond in time.")
                    }
                }
            }
        }
    }

    func reset(runStopCommand: Bool = false) {
        pollTimer?.invalidate()
        pollTimer = nil
        setLaunchToken(UUID())
        if runStopCommand {
            runStopCommandIfNeeded()
        } else {
            clearActiveStopCommand()
        }
        terminateRunningProcess()
        status = .idle
    }

    func stopCurrentService() {
        reset(runStopCommand: true)
    }

    // MARK: - Private

    private func launch(command: String, stopCommand: String?, token: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard self.isCurrentToken(token) else { return }

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
                self.storeActiveStopCommand(stopCommand, for: token)
                self.storeRunningProcess(proc, for: token)
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                self.clearRunningProcess(proc, for: token)

                if proc.terminationStatus != 0 {
                    self.clearActiveStopCommand(for: token)
                    DispatchQueue.main.async {
                        // Don't override if health check already passed.
                        if self.isCurrentToken(token), self.status == .starting {
                            self.status = .failed("Exit code \(proc.terminationStatus): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        }
                    }
                }
            } catch {
                self.clearRunningProcess(proc, for: token)
                self.clearActiveStopCommand(for: token)
                DispatchQueue.main.async {
                    if self.isCurrentToken(token) {
                        self.status = .failed("Failed to run: \(error.localizedDescription)")
                    }
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

    private func setLaunchToken(_ token: UUID) {
        stateQueue.sync {
            launchToken = token
        }
    }

    private func isCurrentToken(_ token: UUID) -> Bool {
        stateQueue.sync {
            launchToken == token
        }
    }

    private func terminateRunningProcess() {
        stateQueue.sync {
            guard let currentProcess else { return }
            if currentProcess.isRunning {
                currentProcess.terminate()
            }
            self.currentProcess = nil
        }
    }

    private func storeRunningProcess(_ process: Process, for token: UUID) {
        stateQueue.sync {
            guard launchToken == token else {
                if process.isRunning {
                    process.terminate()
                }
                return
            }
            currentProcess = process
        }
    }

    private func clearRunningProcess(_ process: Process, for token: UUID) {
        stateQueue.sync {
            guard launchToken == token, currentProcess === process else { return }
            currentProcess = nil
        }
    }

    private func storeActiveStopCommand(_ command: String?, for token: UUID) {
        let normalized = command?.trimmingCharacters(in: .whitespacesAndNewlines)
        stateQueue.sync {
            guard launchToken == token else { return }
            activeStopCommand = (normalized?.isEmpty == false) ? normalized : nil
        }
    }

    private func clearActiveStopCommand(for token: UUID) {
        stateQueue.sync {
            guard launchToken == token else { return }
            activeStopCommand = nil
        }
    }

    private func clearActiveStopCommand() {
        stateQueue.sync {
            activeStopCommand = nil
        }
    }

    private func runStopCommandIfNeeded() {
        let command = stateQueue.sync { activeStopCommand }
        clearActiveStopCommand()

        guard let command, !command.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", command]

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(env["PATH"] ?? "/usr/bin")"
            proc.environment = env

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                // Ignore stop-command failures to avoid surfacing shutdown noise.
            }
        }
    }
}
