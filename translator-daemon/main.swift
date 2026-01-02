import Foundation
import Cocoa
import CoreGraphics

// MARK: - Configuration & Constants
let kDoubleTapInterval: TimeInterval = 0.4 // Relaxed interval
let kHelperLogPrefix = "[GlobalTranslator-Daemon]"

// MARK: - Logger
func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("\(timestamp) \(kHelperLogPrefix) \(message)")
    fflush(stdout) // Ensure logs are flushed immediately
}

// MARK: - Translator (Real DeepSeek API)
class Translator {
    static let shared = Translator()
    
    private let session = URLSession.shared
    
    func translate(text: String, completion: @escaping (String?) -> Void) {
        log("Requesting translation for: \(text.prefix(20))...")
        
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
            log("❌ Error: DEEPSEEK_API_KEY not found in environment variables.")
            completion("[Error: Missing API Key]")
            return
        }
        
        let url = URL(string: "https://api.deepseek.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = "Translate the following text to Chinese (Output only the translation, no extra words): \"\(text)\""
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "You are a professional translator. If the input is Chinese, translate it to English. If the input is English, translate it to Chinese. Output ONLY the translation result, no other words."],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            log("❌ JSON Error: \(error)")
            completion(nil)
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                log("❌ Network Error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else { return }
            
            // Parse Resposne
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let message = first["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    log("✅ Translation received: \(result.prefix(20))...")
                    completion(result)
                } else {
                    let debugStr = String(data: data, encoding: .utf8) ?? "Invalid encoding"
                    log("❌ Decode Error or API Limit. Response: \(debugStr)")
                    completion(nil)
                }
            } catch {
                log("❌ JSON Parse Error: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
}

// MARK: - Automation (Input/Clipboard)
class Automation {
    static let shared = Automation()
    
    // Check Accessibility Permissions
    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // Simulate Key Press (Cmd+Key or plain Key)
    func simulateKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        
        keyDown?.flags = flags
        keyUp?.flags = flags
        
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms delay
        keyUp?.post(tap: .cghidEventTap)
        usleep(50_000)
    }
    
    // State Lock
    var isAutomating = false

    // Complex Action: Select All -> Copy -> Read -> Translate -> Paste
    func performTranslationFlow() {
        guard !isAutomating else { return }
        isAutomating = true
        
        log("🎬 [Action] Triple-Space Detected. Starting Translation Flow...")
        
        // 1. Cmd + A
        log("Step 1/5: ⌘A (Select All)...")
        simulateKey(keyCode: 0, flags: .maskCommand) // 0 is 'a'
        usleep(300_000)
        
        // 2. Cmd + C (Copy)
        log("Step 2/5: ⌘C (Copy)...")
        // CRITICAL FIX: Clear clipboard first to ensure we don't read stale data
        NSPasteboard.general.clearContents()
        
        simulateKey(keyCode: 8, flags: .maskCommand) // 8 is 'c'
        usleep(200_000)
        
        // 3. Read Clipboard (Wait for content)
        waitForClipboardContent(retries: 20) { [weak self] newText in
            guard let self = self else { return }
            
            guard let text = newText, !text.isEmpty else {
                log("❌ [Error] Copy failed (Clipboard empty after timeout).")
                self.isAutomating = false
                return
            }
            log("Step 3/5: ✅ Read Clipboard (\(text.count) chars): \"\(text.prefix(15))...\"")
            
            // 4. Translate
            log("Step 4/5: 🌏 Requesting DeepSeek API...")
            Translator.shared.translate(text: text) { translatedText in
                guard let result = translatedText else {
                    log("❌ [Error] Translation failed.")
                    self.isAutomating = false
                    return
                }
                
                // 5. Paste
                self.writeToClipboard(result)
                
                DispatchQueue.main.async {
                    log("Step 5/5: ⌘V (Paste Result)...")
                    self.simulateKey(keyCode: 9, flags: .maskCommand) // 9 is 'v'
                    log("🎉 [Success] Translation Complete.")
                    
                    // Unlock after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isAutomating = false
                    }
                }
            }
        }
    }
    
    private func waitForClipboardContent(retries: Int, completion: @escaping (String?) -> Void) {
        if retries == 0 {
            completion(nil)
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                completion(text)
            } else {
                // Retry
                self.waitForClipboardContent(retries: retries - 1, completion: completion)
            }
        }
    }
    
    private func writeToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        log("Written to clipboard: \(text.prefix(20))...")
    }
}

// MARK: - Event Tap Monitor
class KeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // State for Triple Tap
    private var spaceTapCount = 0
    private var lastSpaceTime: TimeInterval = 0
    
    func start() {
        // Check permissions
        log("Checking AX Permissions...")
        if !Automation.shared.checkPermissions() {
            log("❌ CRITICAL: Accessibility permissions missing.")
            log("👉 Go to System Settings -> Privacy & Security -> Accessibility and add 'translator-daemon'.")
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.start()
            }
            return
        }
        
        log("Permissions OK. Attempting to create Event Tap...")
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let observer = refcon {
                    let mySelf = Unmanaged<KeyboardMonitor>.fromOpaque(observer).takeUnretainedValue()
                    return mySelf.handle(event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            log("❌ FATAL: Failed to create event tap. Possible causes:")
            log("   1. App Sandbox is ON (Must be OFF).")
            log("   2. Process lacks 'Input Monitoring' permission.")
            exit(1)
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        guard let rls = runLoopSource else {
            log("❌ Failed to create RunLoop Source")
            return
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("✅ Keyboard Monitor started successfully. Waiting for Triple-Space...")
    }
    
    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore events if automation is running
        if Automation.shared.isAutomating {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Space key code is 49
        if keyCode == 49 {
            let now = Date().timeIntervalSince1970
            
            // Check flags (Ignore if Cmd/Shift/Ctrl is held)
            let flags = event.flags
            // Fix: Check flags properly
            if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
                resetState()
                return Unmanaged.passUnretained(event)
            }
            
            if now - lastSpaceTime < kDoubleTapInterval {
                spaceTapCount += 1
            } else {
                spaceTapCount = 1
            }
            
            lastSpaceTime = now
            
            log("Space Tap: \(spaceTapCount)")
            
            if spaceTapCount == 3 {
                log("🔥 Triple Space Detected!")
                spaceTapCount = 0 // Reset
                
                // Trigger automation
                DispatchQueue.main.async {
                    Automation.shared.performTranslationFlow()
                }
                
                // IMPORTANT: Swallow the 3rd space to prevent overwriting the selection
                return nil
            }
        } else {
            // Reset on any other key
            resetState()
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func resetState() {
        spaceTapCount = 0
    }
}

// MARK: - Main Entry Point
log("Daemon launching...")
let monitor = KeyboardMonitor()
monitor.start()
CFRunLoopRun()
