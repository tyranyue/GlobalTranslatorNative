# Global Translator Native 🌍

A lightweight, native macOS menu bar application providing global "Select-to-Translate" functionality using the DeepSeek API.

## Features

- **Global Trigger**: Triple-tap `SPACE` (Select content -> Press `Space` 3 times) to translate text anywhere.
- **Bi-Directional Translation**: Auto-detects Chinese/English and translates significantly.
- **Native & Fast**: Built with SwiftUI and Swift System APIs. No Electron, minimal resource usage.
- **Secure**:
  - No hardcoded secrets.
  - API Key stored in User Defaults.
  - Sandboxing disabled (required for Global Input Monitoring).

## Prerequisites

- macOS 13.0 or later.
- A Valid [DeepSeek API Key](https://platform.deepseek.com/).
- Xcode 15+ (to build from source).

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/GlobalTranslatorNative.git
   cd GlobalTranslatorNative
   ```

2. **Open in Xcode**:
   Double-click `GlobalTranslatorNative.xcodeproj`.

3. **Configure Signing**:
   - Select the `GlobalTranslatorNative` target -> Signing & Capabilities -> Select your Team.
   - Select the `translator-daemon` target -> Signing & Capabilities -> Select your Team.

4. **Build & Run**:
   Press `Cmd + R` to run.

## Setup & Usage

1. **Permissions**:
   - Upon first launch, the app will ask for **Input Monitoring** and **Accessibility** permissions.
   - You **MUST** add both `GlobalTranslatorNative.app` AND the helper binary `translator-daemon` to System Settings -> Privacy & Security -> Input Monitoring / Accessibility.
   - *Note: If permissions fail, remove the entries and re-add them manually.*

2. **Configure API Key**:
   - Click the Menu Bar icon 🌐.
   - Select **Settings...**.
   - Paste your DeepSeek API Key.

3. **Translate**:
   - Highlight any text in any app.
   - Quickly tap `Space` 3 times.
   - Wait a moment for the text to be replaced with the translation.

## Troubleshooting

- **"Access Denied"**: Ensure `translator-daemon` is checked in System Settings -> Input Monitoring.
- **No Response**: Check the API Key in Settings. Check your network connection.
- **Logs**: Open Console.app and search for `GlobalTranslator` to see debug logs.

## License

MIT License. See [LICENSE](LICENSE) file.
