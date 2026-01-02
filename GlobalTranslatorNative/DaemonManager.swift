import Foundation
import AppKit
import Combine

class DaemonManager: ObservableObject {
    static let shared = DaemonManager()
    
    @Published var isRunning = false
    private var process: Process?
    private var outputPipe = Pipe()
    
    private let daemonName = "translator-daemon"
    
    init() {
        // Observer for termination
        NotificationCenter.default.addObserver(self, selector: #selector(processDidTerminate), name: Process.didTerminateNotification, object: nil)
    }
    
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    func start() {
        guard !isRunning else { return }
        
        // 1. Find the binary
        guard let binaryURL = findDaemonBinary() else {
            print("❌ Daemon binary not found!")
            return
        }
        
        print("🚀 Launching daemon at: \(binaryURL.path)")
        
        let task = Process()
        task.executableURL = binaryURL
        task.arguments = [] 
        
        // Redirect stdout for debugging
        task.standardOutput = outputPipe
        
        // Pass API Key via Environment
        var env = ProcessInfo.processInfo.environment
        if let apiKey = UserDefaults.standard.string(forKey: "DeepSeekAPIKey") {
            env["DEEPSEEK_API_KEY"] = apiKey
            print("🔑 Passing API Key to Daemon")
        } else {
            print("⚠️ No API Key found in UserDefaults!")
        }
        task.environment = env
        
        // Termination handler
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                print("⚠️ Daemon terminated.")
            }
        }
        
        do {
            try task.run()
            self.process = task
            self.isRunning = true
            readOutput()
        } catch {
            print("❌ Failed to launch daemon: \(error)")
            self.isRunning = false
        }
    }
    
    func stop() {
        guard let task = process, task.isRunning else { return }
        task.terminate()
        self.process = nil
        self.isRunning = false
    }
    
    private func findDaemonBinary() -> URL? {
        let fileManager = FileManager.default
        
        // Priority 1: Inside Bundle (Production)
        // GlobalTranslatorNative.app/Contents/MacOS/translator-daemon
        if let bundleExecutable = Bundle.main.executableURL {
             let bundlePath = bundleExecutable.deletingLastPathComponent().appendingPathComponent(daemonName)
             if fileManager.fileExists(atPath: bundlePath.path) {
                 return bundlePath
             }
             print("[DaemonManager] Not found in Bundle: \(bundlePath.path)")
        }

        // Priority 2: Standard derived data / debug location
        // Often Xcode puts them in the same folder during debug builds outside the bundle
        if let bundleExecutable = Bundle.main.executableURL {
            let debugPath = bundleExecutable.deletingLastPathComponent().appendingPathComponent(daemonName)
            if fileManager.fileExists(atPath: debugPath.path) {
                return debugPath
            }
             print("[DaemonManager] Not found next to executable: \(debugPath.path)")
        }
        
        return nil
    }
    
    private func readOutput() {
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                // Forward daemon logs to App console
                print("[Daemon] \(string.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }
    
    @objc private func processDidTerminate(notification: Notification) {
        if let proc = notification.object as? Process, proc == self.process {
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}
