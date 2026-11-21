//
//  SoundManager.swift
//  MaemelSolitaer
//
//  Soft, synthesized sound effects so the app needs no audio assets.
//

import AVFoundation

final class SoundManager {
    nonisolated enum Effect: CaseIterable {
        case flip, place, foundation, shuffle, invalid, success, hint, tick
    }

    var isEnabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var isConfigured = false
    private var preparing = false
    private var prepared: [Effect: [Float]]?

    func play(_ effect: Effect) {
        guard isEnabled else { return }
        configureIfNeeded()
        guard let buffer = buffers[effect], !players.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }

        // Round-robin over a few players so overlapping sounds don't cut each other off.
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - Setup

    /// Builds the sounds and starts the audio engine in the background, so the first card
    /// draw doesn't have to wait for it. Safe to call more than once.
    func prepare() {
        guard !isConfigured, !preparing else { return }
        preparing = true
        Task { [weak self] in
            let samples = await Task.detached(priority: .userInitiated) { () -> [Effect: [Float]] in
                Self.activateSession()
                return SoundSynth.renderAll()
            }.value
            self?.prepared = samples
            self?.configureIfNeeded()
        }
    }

    nonisolated private static func activateSession() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        // Ambient: mixes with other audio and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        // Normally prepared in the background already; fall back to doing it here if a sound is needed first.
        if prepared == nil {
            Self.activateSession()
            prepared = SoundSynth.renderAll()
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1) else { return }
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        for (effect, samples) in prepared ?? [:] {
            buffers[effect] = makeBuffer(samples: samples, format: format)
        }
        prepared = nil
        engine.mainMixerNode.outputVolume = 0.8
        try? engine.start()
    }

    private func makeBuffer(samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, sample) in samples.enumerated() {
            channel[i] = max(-1, min(1, sample))
        }
        return buffer
    }
}

/// Builds the sound samples. Pure computation, so it can run off the main thread.
nonisolated enum SoundSynth {
    static let sampleRate = 44_100.0

    static func renderAll() -> [SoundManager.Effect: [Float]] {
        Dictionary(uniqueKeysWithValues: SoundManager.Effect.allCases.map { ($0, synthesize($0)) })
    }

    static func synthesize(_ effect: SoundManager.Effect) -> [Float] {
        switch effect {
        case .flip:
            return noiseBurst(duration: 0.06, decay: 80, smoothing: 0.35, gain: 0.45)
        case .place:
            var samples = tone(170, duration: 0.12, decay: 38, gain: 0.32)
            overlay(&samples, noiseBurst(duration: 0.04, decay: 110, smoothing: 0.15, gain: 0.25), at: 0)
            return samples
        case .foundation:
            return chime([784, 1175], duration: 0.5, gain: 0.26)
        case .hint:
            return chime([660, 990], duration: 0.4, gain: 0.2)
        case .tick:
            return tone(1250, duration: 0.06, decay: 70, gain: 0.12)
        case .invalid:
            var samples = tone(196, duration: 0.14, decay: 16, gain: 0.18)
            overlay(&samples, tone(165, duration: 0.18, decay: 16, gain: 0.18), at: 0.1)
            return samples
        case .shuffle:
            // A riffle: many soft card ticks in quick succession.
            var samples: [Float] = []
            var time = 0.0
            while time < 0.65 {
                let gain = Float.random(in: 0.18...0.32)
                overlay(&samples, noiseBurst(duration: 0.03, decay: 140, smoothing: 0.3, gain: gain), at: time)
                time += Double.random(in: 0.022...0.04)
            }
            return samples
        case .success:
            var samples: [Float] = []
            for (i, frequency) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
                overlay(&samples, chime([frequency, frequency * 2], duration: 0.9, gain: 0.22), at: Double(i) * 0.12)
            }
            return samples
        }
    }

    static func tone(_ frequency: Double, duration: Double, decay: Double, gain: Float) -> [Float] {
        let count = Int(duration * sampleRate)
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            let attack = min(1, t / 0.004)
            return Float(sin(2 * .pi * frequency * t) * exp(-decay * t) * attack) * gain
        }
    }

    static func chime(_ frequencies: [Double], duration: Double, gain: Float) -> [Float] {
        var samples: [Float] = []
        for frequency in frequencies {
            overlay(&samples, tone(frequency, duration: duration, decay: 7, gain: gain / Float(frequencies.count)), at: 0)
        }
        return samples
    }

    /// Low-passed white noise with an exponential decay — sounds like a card snapping.
    static func noiseBurst(duration: Double, decay: Double, smoothing: Float, gain: Float) -> [Float] {
        let count = Int(duration * sampleRate)
        var last: Float = 0
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            last += smoothing * (Float.random(in: -1...1) - last)
            return last * Float(exp(-decay * t)) * gain
        }
    }

    static func overlay(_ base: inout [Float], _ other: [Float], at seconds: Double) {
        let offset = Int(seconds * sampleRate)
        if base.count < offset + other.count {
            base.append(contentsOf: [Float](repeating: 0, count: offset + other.count - base.count))
        }
        for (i, sample) in other.enumerated() {
            base[offset + i] += sample
        }
    }
}
