import AVFoundation
import Speech

enum SpatialDictationResult {
    case success(String)
    case failure
}

final class SpatialSpeechGuide: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func preparePermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(
                        speechStatus == .authorized
                            && granted
                            && self.speechRecognizer?.isAvailable == true
                    )
                }
            }
        }
    }

    func speak(_ text: String) {
        stopDictation()
        activatePlaybackSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.volume = 1

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func beginDictation(onFailure: @escaping () -> Void) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onFailure()
            return
        }

        stopDictation()
        synthesizer.stopSpeaking(at: .immediate)
        latestTranscript = ""

        do {
            try activateDictationSession()
        } catch {
            print("SpatialSpeechGuide dictation session error:", error)
            onFailure()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
            }

            if error != nil {
                self.stopDictation()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("SpatialSpeechGuide audio engine start error:", error)
            stopDictation()
            onFailure()
        }
    }

    func endDictation(completion: @escaping (SpatialDictationResult) -> Void) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()

        let captured = latestTranscript
        recognitionTask?.finish()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.recognitionTask?.cancel()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.activatePlaybackSession()

            let transcript = captured.trimmingCharacters(in: .whitespacesAndNewlines)
            if transcript.isEmpty {
                completion(.failure)
            } else {
                completion(.success(transcript))
            }
        }
    }

    func stopDictation() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        latestTranscript = ""
    }

    func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("SpatialSpeechGuide playback session error:", error)
        }
    }

    private func activateDictationSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .allowBluetooth, .duckOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

extension SpatialSpeechGuide: AVSpeechSynthesizerDelegate {}
