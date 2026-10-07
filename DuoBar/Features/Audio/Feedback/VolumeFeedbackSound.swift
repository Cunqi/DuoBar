import AppKit
import Foundation


@MainActor
enum VolumeFeedbackSound {
    private static let sound: NSSound? = {
        guard let systemSound = NSSound(named: NSSound.Name("Tink")),
              let sound = systemSound.copy() as? NSSound
        else { return nil }

        sound.volume = 0.18
        sound.loops = false
        return sound
    }()

    @discardableResult
    static func play(on playbackDeviceIdentifier: String?) -> Bool {
        guard let sound else { return false }

        // A nil identifier intentionally follows the current system default output.
        sound.playbackDeviceIdentifier = playbackDeviceIdentifier
        if sound.isPlaying {
            sound.stop()
            sound.currentTime = 0
        }
        if sound.play() {
            return true
        }

        // Device UIDs are public Core Audio identifiers, but some output drivers
        // decline explicit routing. Let AppKit retry on the current default route.
        guard playbackDeviceIdentifier != nil else { return false }
        sound.playbackDeviceIdentifier = nil
        return sound.play()
    }
}
