//  ElevenLabsService.swift
//  ClipCheck

import AVFoundation
import Foundation

@Observable
final class ElevenLabsService: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    enum PlaybackState { case idle, loading, playing }
    private(set) var state: PlaybackState = .idle

    private var player: AVAudioPlayer?
    private var synthesizer: AVSpeechSynthesizer?

    func speak(_ text: String) {
        if state == .playing { stop(); return }
        guard state == .idle else { return }
        state = .loading

        let key = Secrets.elevenLabsAPIKey
        guard !key.isEmpty, key != "YOUR_ELEVENLABS_API_KEY_HERE" else {
            speakOnDevice(text)
            return
        }

        Task {
            do {
                let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue(key, forHTTPHeaderField: "xi-api-key")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.timeoutInterval = 15
                req.httpBody = try JSONSerialization.data(withJSONObject: [
                    "text": text,
                    "model_id": "eleven_multilingual_v2"
                ])

                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0

                guard (200...299).contains(code), data.count > 100 else {
                    print("[TTS] ElevenLabs HTTP \(code), falling back to on-device")
                    await MainActor.run { self.speakOnDevice(text) }
                    return
                }

                await MainActor.run { self.playData(data) }
            } catch {
                print("[TTS] ElevenLabs error: \(error), falling back to on-device")
                await MainActor.run { self.speakOnDevice(text) }
            }
        }
    }

    func stop() {
        player?.stop(); player = nil
        synthesizer?.stopSpeaking(at: .immediate); synthesizer = nil
        state = .idle
    }

    // MARK: - ElevenLabs playback

    private func playData(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.play()
            player = p
            state = .playing
        } catch {
            print("[TTS] Playback error: \(error)")
            state = .idle
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.player = nil
            self?.state = .idle
        }
    }

    // MARK: - On-device fallback

    private func speakOnDevice(_ text: String) {
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        synthesizer = synth
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utt.pitchMultiplier = 1.05
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        synth.speak(utt)
        state = .playing
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.synthesizer = nil
            self?.state = .idle
        }
    }
}
