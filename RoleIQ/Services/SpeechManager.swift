//
//  SpeechManager.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 03/08/26.
//


import Speech
import AVFoundation
import SwiftUI

@Observable
final class SpeechManager {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var transcript = ""
    var isRecording = false
    var error: String?

    /// Live mic amplitude, 0...1, smoothed. Drives the orb's listening reaction.
    var level: CGFloat = 0

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() throws {
        task?.cancel()
        task = nil
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Guard against a leftover tap from a previous session — installing a
        // second tap on the same bus throws 'nullptr == Tap()'.
        inputNode.removeTap(onBus: 0)

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateLevel(from: buffer)   // <-- reuse the same buffer, no 2nd tap
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.25)) { self.level = 0 }
        }
    }

    /// Compute RMS amplitude from the mic buffer and smooth it onto `level`.
    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        var sum: Float = 0
        for i in 0..<n {
            let s = channel[i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(n))

        // Speech RMS is typically ~0.02–0.2; scale into a lively 0...1 range.
        let scaled = min(1, CGFloat(rms) * 8)

        Task { @MainActor in
            // Attack fast, release slow — feels responsive but not jittery.
            let target = scaled
            let smoothing: CGFloat = target > self.level ? 0.5 : 0.15
            self.level += (target - self.level) * smoothing
        }
    }
}
