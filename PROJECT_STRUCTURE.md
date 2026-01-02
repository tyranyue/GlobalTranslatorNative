# Global Translator Native - Engineering Guide

## 1. Project Structure (Directory Tree)

```text
GlobalTranslatorNative/
├── GlobalTranslatorNative.xcodeproj   # Main Xcode Project
├── GlobalTranslatorNative/            # SwiftUI App Source
│   ├── GlobalTranslatorNativeApp.swift # App Entry (MenuBarExtra)
│   ├── DaemonManager.swift             # Manages the background process
│   ├── PermissionHelper.swift          # Accessibility Permission Helper
│   └── Assets.xcassets
└── translator-daemon/                 # Command Line Tool Source
    └── main.swift                      # Core Logic (EventTap, State Machine)
```

## 2. Xcode Setup Instructions

### Targets
1.  **GlobalTranslatorNative** (macOS App)
    *   **App Sandbox**: **NO** (Must be disabled to launch the daemon and manage permissions easily).
    *   **Signing**: Development.
2.  **translator-daemon** (Command Line Tool)
    *   Create a new Target -> macOS -> Command Line Tool.
    *   Name: `translator-daemon`
    *   **Signing**: **REQUIRED** (Must be signed to hold Accessibility permissions).
    *   **Hardened Runtime**: YES (Recommended).
    *   **Sandbox**: **NO** (Strictly NO).

### Build Dependencies
*   The App depends on the Daemon.
*   In Xcode: `GlobalTranslatorNative` Target -> **Build Phases** -> **Copy Files**.
    *   Destination: `Executables` (or `Wrapper` -> `Contents/MacOS`).
    *   Add the `translator-daemon` product here.
    *   *Note*: This ensures the binary is copied into `GlobalTranslatorNative.app/Contents/MacOS/` when building.

---

## 3. Info.plist & Entitlements

### GlobalTranslatorNative (App)
*   **Privacy - Accessibility Usage Description**: "We need accessibility permissions to manage the translation helper."
*   **App Sandbox**: Ensure this entitlement is REMOVED from the `.entitlements` file.

### translator-daemon (CLI)
*   **Privacy - Input Monitoring Usage Description**: "Monitors keyboard for the triple-space trigger."
    *   *Note*: CLI tools embed Info.plist entries via "Create Info.plist Section in Binary" build setting `CREATE_INFOPLIST_SECTION_IN_BINARY = YES` and adding keys there, OR relying on the fact it's a daemon. Usually, the *Permissions Prompt* will appear generically for the binary path.

---

## 4. Debugging Guide

### How to Run in Xcode
1.  Select `GlobalTranslatorNative` scheme.
2.  Build & Run (Cmd+R).
3.  The Menu Bar icon (Globe) should appear.
4.  Click "Start Translator".
    *   **First Run**: You should see a "Privacy & Security" prompt (or you strictly need to check Xcode Console logs).
    *   The App Console will show logs tagged `[Daemon]`.
    *   If `[Daemon]` says "⚠️ Accessibility permissions missing", click "Open Permissions" in the menu.
    *   In System Settings, if you don't see the app, try running the **CLI binary directly** in Terminal once to force the prompt:
        ```bash
        ./path/to/translator-daemon
        ```
    *   **Important**: Removing the App/Binary from the "Accessibility" list in System Settings is often required to reset permissions if they get stuck.

### Terminal Debugging
You can run the daemon standalone to test the keyboard tap without the UI:
```bash
# Build destination usually in DerivedData
cd ~/Library/Developer/Xcode/DerivedData/GlobalTranslatorNative-.../Build/Products/Debug/
./translator-daemon
```

---

## 5. Packaging (DMG)

1.  **Archive**: Update scheme to Release. Product -> Archive.
2.  **Export**: Export as "Direct Distribution" (No Notarization for local test) or "Developer ID" (for Notarization).
3.  **Verify Bundle**:
    *   Right click `GlobalTranslatorNative.app` -> Show Package Contents.
    *   Ensure `Contents/MacOS/translator-daemon` exists.
4.  **Create DMG**:
    *   Use Disk Utility -> File -> New Image -> Image from Folder.
    *   Or use a tool like `create-dmg`.

---

## 6. Architecture Notes

*   **Logic**: The `main.swift` in `translator-daemon` runs a `CFRunLoop`. It uses `CGEvent.tapCreate` to intercept the space bar.
*   **Input Simulation**: Uses `CGEventPost` to simulate Cmd+A/C/V.
*   **Clipboard**: Polling strategy is used to ensure `NSPasteboard` has updated data before translating.
