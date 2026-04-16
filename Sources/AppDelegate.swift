import AppKit
import UserNotifications

enum AppState {
    case idle
    case recording(RecordingMode)
    case processing

    var menuTitle: String {
        switch self {
        case .idle: return "Idle"
        case .recording(let mode):
            switch mode {
            case .transcription: return "🔴 REC (Transcribe)"
            case .translation: return "🔴 REC (Translate)"
            case .qa: return "🔴 REC (Q&A)"
            }
        case .processing: return "⏳ Processing..."
        }
    }

    var statusItemTitle: String {
        switch self {
        case .idle: return "🎙"
        case .recording: return "🔴"
        case .processing: return "⏳"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private let hotkeyManager = HotkeyManager()
    private let audioRecorder = AudioRecorder()
    private var currentState: AppState = .idle {
        didSet { updateUI() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== VoiceInline Starting ===")
        PermissionChecker.checkAll()
        requestNotificationPermission()
        setupStatusBar()
        setupHotkeys()
        print("=== VoiceInline Ready ===")
        print("Hotkeys:")
        print("  Ctrl+Shift+1  →  Speech to Text")
        print("  Ctrl+Shift+2  →  Translate to English")
        print("  Ctrl+Shift+3  →  Q&A with LLM")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎙"

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupHotkeys() {
        hotkeyManager.onKeyDown = { [weak self] mode in
            self?.startRecording(mode: mode)
        }
        hotkeyManager.onKeyUp = { [weak self] mode in
            self?.stopRecordingAndProcess(mode: mode)
        }
        hotkeyManager.start()
    }

    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusItem.button?.title = self.currentState.statusItemTitle
            self.statusMenuItem.title = "Status: \(self.currentState.menuTitle)"
        }
    }

    private func startRecording(mode: RecordingMode) {
        guard case .idle = currentState else { return }

        do {
            try audioRecorder.startRecording()
            currentState = .recording(mode)
            print("Recording started (\(mode))")
        } catch {
            print("Failed to start recording: \(error)")
            showNotification(title: "Recording Error", body: error.localizedDescription)
        }
    }

    private func stopRecordingAndProcess(mode: RecordingMode) {
        guard case .recording = currentState else { return }

        guard let audioURL = audioRecorder.stopRecording() else {
            currentState = .idle
            showNotification(title: "Error", body: "No audio was recorded.")
            return
        }

        currentState = .processing
        print("Recording stopped. Processing...")

        switch mode {
        case .transcription:
            handleTranscription(audioURL: audioURL)
        case .translation:
            handleTranslation(audioURL: audioURL)
        case .qa:
            handleQA(audioURL: audioURL)
        }
    }

    private func handleTranscription(audioURL: URL) {
        WhisperAPI.process(audioURL: audioURL, endpoint: .transcription) { [weak self] result in
            self?.audioRecorder.cleanup()
            switch result {
            case .success(let text):
                print("Transcription: \(text)")
                DispatchQueue.main.async {
                    TextInserter.insertText(text)
                    self?.currentState = .idle
                }
            case .failure(let error):
                print("Transcription error: \(error)")
                self?.showNotification(title: "Transcription Error", body: error.localizedDescription)
                DispatchQueue.main.async { self?.currentState = .idle }
            }
        }
    }

    private func handleTranslation(audioURL: URL) {
        WhisperAPI.process(audioURL: audioURL, endpoint: .translation) { [weak self] result in
            self?.audioRecorder.cleanup()
            switch result {
            case .success(let text):
                print("Translation: \(text)")
                DispatchQueue.main.async {
                    TextInserter.insertText(text)
                    self?.currentState = .idle
                }
            case .failure(let error):
                print("Translation error: \(error)")
                self?.showNotification(title: "Translation Error", body: error.localizedDescription)
                DispatchQueue.main.async { self?.currentState = .idle }
            }
        }
    }

    private func handleQA(audioURL: URL) {
        WhisperAPI.process(audioURL: audioURL, endpoint: .transcription) { [weak self] result in
            self?.audioRecorder.cleanup()
            switch result {
            case .success(let question):
                print("Q&A question: \(question)")
                LLMAPI.ask(question: question) { [weak self] llmResult in
                    switch llmResult {
                    case .success(let answer):
                        print("Q&A answer: \(answer)")
                        DispatchQueue.main.async {
                            TextInserter.insertText(answer)
                            self?.currentState = .idle
                        }
                    case .failure(let error):
                        print("LLM error: \(error)")
                        self?.showNotification(title: "Q&A Error", body: error.localizedDescription)
                        DispatchQueue.main.async { self?.currentState = .idle }
                    }
                }
            case .failure(let error):
                print("Transcription error (Q&A): \(error)")
                self?.showNotification(title: "Q&A Error", body: error.localizedDescription)
                DispatchQueue.main.async { self?.currentState = .idle }
            }
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    @objc private func quitApp() {
        hotkeyManager.stop()
        NSApplication.shared.terminate(nil)
    }
}
