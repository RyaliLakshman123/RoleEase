//
//  VoiceSynthesizer.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 03/08/26.
//

import AVFoundation

@Observable
final class VoiceSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false
    var revealedText = ""   // fills in progressively as speech plays

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        // The recording flow leaves the shared audio session in .record mode,
        // which is input-only and cannot play audio — that's why questions after
        // the first went silent. Claim a playback-capable session before every
        // utterance so the synthesizer is always audible.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)

        revealedText = ""
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-GB.Daniel")
            ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.95
        utterance.preUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        guard let r = Range(range, in: utterance.speechString) else { return }
        revealedText = String(utterance.speechString[..<r.upperBound])
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { isSpeaking = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        isSpeaking = false
        revealedText = u.speechString
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { isSpeaking = false }
}
