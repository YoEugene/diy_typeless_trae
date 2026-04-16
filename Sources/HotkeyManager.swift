import AppKit
import Carbon

enum RecordingMode {
    case transcription
    case translation
    case qa
}

final class HotkeyManager {
    var onKeyDown: ((RecordingMode) -> Void)?
    var onKeyUp: ((RecordingMode) -> Void)?

    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var activeMode: RecordingMode?
    private var activeKeys: Set<UInt16> = []

    private let key1: UInt16 = 18  // kVK_ANSI_1
    private let key2: UInt16 = 19  // kVK_ANSI_2
    private let key3: UInt16 = 20  // kVK_ANSI_3

    func start() {
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event)
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    func stop() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m) }
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        keyDownMonitor = nil
        keyUpMonitor = nil
        flagsMonitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers: NSEvent.ModifierFlags = [.control, .shift]
        guard modifiers.contains(requiredModifiers) else { return }

        let keyCode = event.keyCode
        let mode: RecordingMode?
        switch keyCode {
        case key1: mode = .transcription
        case key2: mode = .translation
        case key3: mode = .qa
        default: mode = nil
        }

        guard let m = mode else { return }
        guard activeMode == nil else { return }

        activeMode = m
        activeKeys.insert(keyCode)
        onKeyDown?(m)
    }

    private func handleKeyUp(_ event: NSEvent) {
        let keyCode = event.keyCode
        guard activeKeys.contains(keyCode) else { return }
        activeKeys.remove(keyCode)
        if let mode = activeMode {
            activeMode = nil
            onKeyUp?(mode)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard activeMode != nil else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers: NSEvent.ModifierFlags = [.control, .shift]

        if !modifiers.contains(requiredModifiers) {
            if let mode = activeMode {
                activeMode = nil
                activeKeys.removeAll()
                onKeyUp?(mode)
            }
        }
    }
}
