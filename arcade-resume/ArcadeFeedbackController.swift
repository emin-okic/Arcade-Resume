import AVFoundation
import UIKit

enum MoveDirection {
    case left
    case right
}

@MainActor
final class ArcadeFeedbackController {
    private let engine = AVAudioEngine()
    private let musicNode = AVAudioPlayerNode()
    private let effectsNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let softFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private var isConfigured = false
    private var isMusicPlaying = false

    func startBackgroundMusic() {
        configureAudioIfNeeded()
        guard !isMusicPlaying else { return }

        let buffer = makeBackgroundMusicBuffer()
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
        musicNode.play()
        isMusicPlaying = true
    }

    func playJump() {
        softFeedback.impactOccurred(intensity: 0.65)
        playTone(frequency: 520, duration: 0.09, volume: 0.18, shape: .square, glideTo: 780)
    }

    func playMoveButtonPress() {
        softFeedback.impactOccurred(intensity: 0.4)
    }

    func playMoveStep(direction: MoveDirection) {
        let frequency = direction == .left ? 190.0 : 230.0
        playTone(frequency: frequency, duration: 0.045, volume: 0.09, shape: .square, glideTo: frequency * 0.82)
    }

    func playBlockReveal() {
        notificationFeedback.notificationOccurred(.success)
        playTone(frequency: 880, duration: 0.08, volume: 0.2, shape: .square)
        playTone(frequency: 1_320, duration: 0.11, volume: 0.16, shape: .triangle, delay: 0.06)
    }

    func playClose() {
        softFeedback.impactOccurred(intensity: 0.55)
        playTone(frequency: 260, duration: 0.06, volume: 0.12, shape: .triangle, glideTo: 180)
    }

    func playLanding() {
        softFeedback.impactOccurred(intensity: 0.45)
        playTone(frequency: 150, duration: 0.05, volume: 0.11, shape: .triangle)
    }

    func playReset() {
        impactFeedback.impactOccurred(intensity: 0.75)
        playTone(frequency: 330, duration: 0.08, volume: 0.18, shape: .square)
        playTone(frequency: 220, duration: 0.12, volume: 0.15, shape: .square, delay: 0.07)
    }

    private func configureAudioIfNeeded() {
        guard !isConfigured else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        engine.attach(musicNode)
        engine.attach(effectsNode)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        engine.connect(effectsNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.75
        try? engine.start()

        impactFeedback.prepare()
        softFeedback.prepare()
        notificationFeedback.prepare()
        isConfigured = true
    }

    private enum WaveShape {
        case square
        case triangle
    }

    private func playTone(
        frequency: Double,
        duration: Double,
        volume: Float,
        shape: WaveShape,
        glideTo endFrequency: Double? = nil,
        delay: Double = 0
    ) {
        if delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                playTone(
                    frequency: frequency,
                    duration: duration,
                    volume: volume,
                    shape: shape,
                    glideTo: endFrequency
                )
            }
            return
        }

        configureAudioIfNeeded()

        let buffer = makeToneBuffer(
            frequency: frequency,
            duration: duration,
            volume: volume,
            shape: shape,
            glideTo: endFrequency
        )
        effectsNode.scheduleBuffer(buffer, at: nil)

        if !effectsNode.isPlaying {
            effectsNode.play()
        }
    }

    private func makeToneBuffer(
        frequency: Double,
        duration: Double,
        volume: Float,
        shape: WaveShape,
        glideTo endFrequency: Double?
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }
        var phase = 0.0

        for frame in 0..<Int(frameCount) {
            let progress = Double(frame) / Double(max(Int(frameCount) - 1, 1))
            let currentFrequency = frequency + ((endFrequency ?? frequency) - frequency) * progress
            phase += currentFrequency / format.sampleRate
            phase.formTruncatingRemainder(dividingBy: 1)

            let envelope = envelopeValue(progress)
            let sample: Double
            switch shape {
            case .square:
                sample = phase < 0.5 ? 1 : -1
            case .triangle:
                sample = 4 * abs(phase - 0.5) - 1
            }

            channel[frame] = Float(sample) * volume * Float(envelope)
        }

        return buffer
    }

    private func makeBackgroundMusicBuffer() -> AVAudioPCMBuffer {
        let tempo = 132.0
        let beatDuration = 60.0 / tempo
        let melody: [(frequency: Double, beats: Double)] = [
            (523.25, 0.5), (659.25, 0.5), (783.99, 0.5), (659.25, 0.5),
            (587.33, 0.5), (739.99, 0.5), (880.00, 1.0),
            (783.99, 0.5), (659.25, 0.5), (523.25, 0.5), (392.00, 0.5),
            (440.00, 0.5), (523.25, 0.5), (659.25, 1.0)
        ]
        let bass: [(frequency: Double, beats: Double)] = [
            (130.81, 1), (196.00, 1), (146.83, 1), (220.00, 1),
            (174.61, 1), (261.63, 1), (196.00, 1), (146.83, 1)
        ]

        let duration = melody.reduce(0) { $0 + $1.beats * beatDuration }
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        writeSequence(melody, beatDuration: beatDuration, volume: 0.075, shape: .triangle, into: channel, frameLimit: Int(frameCount))
        writeSequence(bass, beatDuration: beatDuration, volume: 0.045, shape: .square, into: channel, frameLimit: Int(frameCount))
        return buffer
    }

    private func writeSequence(
        _ notes: [(frequency: Double, beats: Double)],
        beatDuration: Double,
        volume: Float,
        shape: WaveShape,
        into channel: UnsafeMutablePointer<Float>,
        frameLimit: Int
    ) {
        var cursor = 0
        var phase = 0.0

        for note in notes {
            let noteFrames = Int(note.beats * beatDuration * format.sampleRate)
            for offset in 0..<noteFrames where cursor + offset < frameLimit {
                let progress = Double(offset) / Double(max(noteFrames - 1, 1))
                phase += note.frequency / format.sampleRate
                phase.formTruncatingRemainder(dividingBy: 1)

                let sample: Double
                switch shape {
                case .square:
                    sample = phase < 0.5 ? 1 : -1
                case .triangle:
                    sample = 4 * abs(phase - 0.5) - 1
                }

                channel[cursor + offset] += Float(sample) * volume * Float(envelopeValue(progress))
            }
            cursor += noteFrames
        }
    }

    private func envelopeValue(_ progress: Double) -> Double {
        let attack = min(progress / 0.08, 1)
        let release = min((1 - progress) / 0.14, 1)
        return max(0, min(attack, release))
    }
}
