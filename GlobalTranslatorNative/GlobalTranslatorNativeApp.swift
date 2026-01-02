import SwiftUI

@main
struct GlobalTranslatorNativeApp: App {
    @StateObject private var daemonManager = DaemonManager.shared
    
    var body: some Scene {
        // 1. Menu Bar Item
        MenuBarExtra("Global Translator", systemImage: "globe") {
            // Status
            Text(daemonManager.isRunning ? "Status: Running" : "Status: Stopped")
                .foregroundColor(daemonManager.isRunning ? .green : .red)
            
            Divider()
            
            // Toggle
            Button(daemonManager.isRunning ? "Stop Translator" : "Start Translator") {
                daemonManager.toggle()
            }
            
            Divider()
            
            // Settings Link
            // Note: This relies on the "Settings" scene below
            if #available(macOS 14.0, *) {
                SettingsLink {
                   Text("Settings...")
                }
            } else {
               Button("Settings...") {
                   NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                   NSApp.activate(ignoringOtherApps: true)
               }
            }
            
            // Permissions Shortcut
            Button("Open Permissions...") {
                PermissionHelper.openSystemSettings()
            }
            
            Divider()
            
            Button("Quit") {
                daemonManager.stop()
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu) // Ensure standard menu style
        
        // 2. Settings Window
        Settings {
            SettingsView()
                .frame(width: 400, height: 200)
        }
    }
}

// Simple Settings View for API Key
struct SettingsView: View {
    @AppStorage("DeepSeekAPIKey") private var apiKey: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("DeepSeek API Configuration")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Enter your DeepSeek API Key here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
