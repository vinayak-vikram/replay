//
//  SilenceDetector.swift
//  replay
//
//  Created by Vinayak Vikram on 5/20/26.
//

// Called exclusively from the AVAudioEngine tap thread.
// All state is intentionally non-isolated — only one thread touches it.
final class SilenceDetector {

    // dB level the instrument must exceed before we start watching for silence.
    // Set conservatively for music: a note needs to be reasonably loud to arm.
    nonisolated(unsafe) var activationThresholdDB: Float = -35
    // dB below which the signal counts as silent.
    nonisolated(unsafe) var silenceThresholdDB: Float = -50
    // Seconds of continuous silence needed to fire.
    nonisolated(unsafe) var silenceDuration: Double = 2.0

    // Fired on the audio tap thread; callers must hop to main actor themselves.
    nonisolated(unsafe) var onActivated: (() -> Void)?
    nonisolated(unsafe) var onSilenceDetected: (() -> Void)?

    nonisolated(unsafe) private var hasActivated = false
    nonisolated(unsafe) private var silenceSamples = 0
    nonisolated(unsafe) private var sampleRate: Double = 44_100

    nonisolated func configure(sampleRate: Double) {
        self.sampleRate = sampleRate
        reset()
    }

    nonisolated func process(db: Float, frameCount: Int) {
        if !hasActivated {
            if db >= activationThresholdDB {
                hasActivated = true
                onActivated?()
            }
            return
        }

        if db < silenceThresholdDB {
            silenceSamples += frameCount
            if Double(silenceSamples) / sampleRate >= silenceDuration {
                onSilenceDetected?()
                reset()
            }
        } else {
            silenceSamples = 0
        }
    }

    nonisolated func reset() {
        hasActivated = false
        silenceSamples = 0
    }
}
