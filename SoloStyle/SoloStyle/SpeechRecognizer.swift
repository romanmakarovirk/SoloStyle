//
//  SpeechRecognizer.swift
//  SoloStyle
//
//  Real-time speech recognition using Apple Speech framework
//

import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechRecognizer {

    // MARK: - State

    var transcript = ""
    var isRecording = false
    var errorMessage: String?
    var isAuthorized = false

    // MARK: - Private

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Init

    init(locale: Locale = Locale(identifier: "ru-RU")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Permissions

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.isAuthorized = true
                    self.errorMessage = nil
                case .denied:
                    self.isAuthorized = false
                    self.errorMessage = L.vcMicDenied
                case .restricted:
                    self.isAuthorized = false
                    self.errorMessage = L.vcMicDenied
                case .notDetermined:
                    self.isAuthorized = false
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Start Recording

    func startRecording() throws {
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        recognitionRequest.shouldReportPartialResults = true

        // Start recognition task
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // "Request was cancelled" — expected when stopping
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    self.stopRecording()
                }

                if result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        transcript = ""
        isRecording = true
        errorMessage = nil
    }

    // MARK: - Stop Recording

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Reset

    func reset() {
        stopRecording()
        transcript = ""
        errorMessage = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case requestCreationFailed
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .requestCreationFailed:
            "Не удалось создать запрос на распознавание речи"
        case .recognizerUnavailable:
            "Распознавание речи недоступно на этом устройстве"
        }
    }
}
