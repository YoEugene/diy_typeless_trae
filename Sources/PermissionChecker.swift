import Foundation

struct PermissionChecker {
    static func checkAll() {
        checkAccessibility()
        checkMicrophone()
        checkAPIKeys()
    }

    static func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️  Accessibility permission is NOT granted.")
            print("   Go to: System Settings → Privacy & Security → Accessibility")
            print("   Add this application to the allowed list.")
            print("   Global hotkeys and Cmd+V simulation require this permission.")

            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        } else {
            print("✅ Accessibility permission granted.")
        }
    }

    static func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("✅ Microphone permission granted.")
        case .notDetermined:
            print("⏳ Microphone permission not yet determined. Will request on first use.")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("✅ Microphone permission granted.")
                } else {
                    print("❌ Microphone permission denied.")
                }
            }
        case .denied, .restricted:
            print("❌ Microphone permission is DENIED.")
            print("   Go to: System Settings → Privacy & Security → Microphone")
            print("   Enable microphone access for this application.")
        @unknown default:
            print("⚠️  Unknown microphone permission status.")
        }
    }

    static func checkAPIKeys() {
        if ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil {
            print("❌ OPENAI_API_KEY environment variable is not set.")
            print("   This is required for speech-to-text and translation.")
            print("   Export it before running: export OPENAI_API_KEY=sk-...")
        } else {
            print("✅ OPENAI_API_KEY is set.")
        }

        if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] == nil {
            print("⚠️  ANTHROPIC_API_KEY is not set. Q&A mode will use OpenAI GPT instead.")
        } else {
            print("✅ ANTHROPIC_API_KEY is set.")
        }
    }
}

import AVFoundation
