import AVFoundation
import Foundation
import Speech

// Voice input pipeline for LimeIME's keyboard extension.
//
// Mandates per docs/IOS_VOICE_INPUT.md §5:
//   - On-device recognition only (`requiresOnDeviceRecognition = true`).
//     Keyboard extensions are not allowed to send audio off-device per
//     App Store policy.
//   - Permission gate: both `SFSpeechRecognizer.authorizationStatus()` and
//     `AVAudioSession.recordPermission` must be authorized before the
//     audio engine starts.
//   - Auto-stop on silence: 1.5 s of no transcription delta triggers
//     `endAudio()` so the recognizer finalizes the partial.
//
// All callbacks fire on the main thread. The controller is single-shot —
// `start()` while already listening is a no-op; call `stop()` (commit
// partial as final) or `cancel()` (discard) first.
protocol VoiceInputControllerDelegate: AnyObject {
    func voiceInputDidUpdatePartial(text: String)
    func voiceInputDidFinish(text: String)
    func voiceInputDidFail(_ reason: VoiceInputController.Failure)
    func voiceInputDidEnterState(_ state: VoiceInputController.State)
}

final class VoiceInputController {

    enum State {
        case idle
        case requestingPermission
        case listening
        case finalizing
        case error
    }

    enum Failure {
        case speechAuthDenied
        case micAuthDenied
        case notSupported
        case keyboardExtensionMicUnavailable
        case engineError(Error)
    }

    weak var delegate: VoiceInputControllerDelegate?
    static let canCaptureAudioInKeyboardExtension = false

    private(set) var state: State = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.voiceInputDidEnterState(self.state)
            }
        }
    }

    private let locale: Locale
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastPartial: String = ""

    private let silenceTimeout: TimeInterval = 1.5

    init(locale: Locale) {
        self.locale = locale
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    deinit {
        teardownAudio()
    }

    func start() {
        guard state == .idle else { return }
        guard Self.canCaptureAudioInKeyboardExtension else {
            transitionToError(.keyboardExtensionMicUnavailable)
            return
        }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            transitionToError(.notSupported)
            return
        }
        // Simulator usually lacks the on-device speech model — bypass the
        // check so engineers can exercise the flow during testing. Release
        // builds still enforce on-device per App Store policy.
        #if !targetEnvironment(simulator)
        guard recognizer.supportsOnDeviceRecognition else {
            transitionToError(.notSupported)
            return
        }
        #endif
        state = .requestingPermission
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard let self = self else { return }
            guard speechStatus == .authorized else {
                self.transitionToError(.speechAuthDenied)
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                guard let self = self else { return }
                guard granted else {
                    self.transitionToError(.micAuthDenied)
                    return
                }
                DispatchQueue.main.async { self.beginRecognitionSession() }
            }
        }
    }

    // Stop and finalize whatever the recogniser has so far.
    func stop() {
        guard state == .listening || state == .requestingPermission else { return }
        state = .finalizing
        request?.endAudio()
        silenceTimer?.invalidate()
    }

    // Discard the partial entirely — no commit.
    func cancel() {
        task?.cancel()
        teardownAudio()
        lastPartial = ""
        state = .idle
    }

    // MARK: - Internals

    private func beginRecognitionSession() {
        guard let recognizer = recognizer else {
            transitionToError(.notSupported)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        // On-device mandatory in release; simulator falls back to cloud
        // because no offline model is installed there.
        #if targetEnvironment(simulator)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        #else
        request.requiresOnDeviceRecognition = true
        #endif
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.taskHint = .dictation
        }
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            // .playAndRecord (vs .record) is the only category that reliably
            // lets a keyboard extension grab the mic when the host app may
            // also be using audio. .duckOthers softly pauses other audio.
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            transitionToError(.engineError(error))
            return
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Crash guard: keyboard extensions can return a zero-channel format
        // when audio session activation didn't actually claim the mic
        // (host app holds it, hardware unavailable). Bailing here prevents
        // the "required condition is false: format.mChannelsPerFrame" crash
        // inside `installTap`.
        guard format.channelCount > 0 else {
            transitionToError(.engineError(NSError(
                domain: "LimeVoiceInput", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone unavailable"])))
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            transitionToError(.engineError(error))
            return
        }

        lastPartial = ""
        state = .listening
        scheduleSilenceTimer()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error as NSError? {
                // Cancellation by `cancel()` is not an error from the user's POV.
                if error.domain != "kAFAssistantErrorDomain" || error.code != 209 {
                    self.transitionToError(.engineError(error))
                }
                self.teardownAudio()
                return
            }
            guard let result = result else { return }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                self.lastPartial = text
                self.teardownAudio()
                self.state = .idle
                DispatchQueue.main.async {
                    self.delegate?.voiceInputDidFinish(text: text)
                }
            } else if text != self.lastPartial {
                self.lastPartial = text
                self.scheduleSilenceTimer()
                DispatchQueue.main.async {
                    self.delegate?.voiceInputDidUpdatePartial(text: text)
                }
            }
        }
    }

    private func scheduleSilenceTimer() {
        silenceTimer?.invalidate()
        let timer = Timer(timeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            self?.stop()
        }
        RunLoop.main.add(timer, forMode: .common)
        silenceTimer = timer
    }

    private func teardownAudio() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // Always remove the tap unconditionally — leaving a stale tap
        // installed between sessions is the most common crash trigger
        // on the next `installTap` ("required condition is false: nullptr == Tap()").
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        request = nil
        task = nil
    }

    private func transitionToError(_ reason: Failure) {
        teardownAudio()
        state = .error
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.voiceInputDidFail(reason)
            self?.state = .idle
        }
    }
}
