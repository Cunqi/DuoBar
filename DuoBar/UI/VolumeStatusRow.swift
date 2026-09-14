import SwiftUI

struct VolumeStatusRow: View {
    let volume: OutputVolumeStatus
    let hasOutputDevice: Bool
    let playbackDeviceIdentifier: String?
    let onSetVolume: (Double) -> Bool
    let onSetMuted: (Bool) -> Bool

    @State private var feedbackInteraction = VolumeFeedbackInteraction()

    var body: some View {
        HStack(spacing: 11) {
            muteControl
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Volume")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Text(stateText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if volume.isSettable, let level = volume.level {
                    Slider(
                        value: Binding(
                            get: { level },
                            set: handleUserVolumeChange
                        ),
                        in: 0...1,
                        onEditingChanged: handleSliderEditingChanged
                    )
                    .controlSize(.mini)
                    .accessibilityLabel("Output volume")
                    .accessibilityValue(stateText)
                } else {
                    Text(hasOutputDevice ? "Controlled by device" : "Volume unavailable")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var muteControl: some View {
        if volume.isMuteSettable {
            Button {
                handleUserMuteChange()
            } label: {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(volume.isMuted ? "Unmute" : "Mute")
            .accessibilityLabel(volume.isMuted ? "Unmute output" : "Mute output")
        } else {
            Image(systemName: volumeSymbol)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var volumeSymbol: String {
        guard let percentage = volume.percentage else { return "speaker" }
        if volume.isMuted || percentage == 0 { return "speaker.slash.fill" }
        switch percentage {
        case 1...33: return "speaker.wave.1"
        case 34...66: return "speaker.wave.2"
        default: return "speaker.wave.3"
        }
    }

    private var stateText: String {
        if volume.isMuted { return "Muted" }
        return volume.percentage.map { "\($0)%" } ?? "—"
    }

    private func handleUserVolumeChange(_ level: Double) {
        beginSliderInteractionIfNeeded()
        guard feedbackInteraction.allowsVolumeUpdates else {
            feedbackInteraction.recordVolumeUpdate(
                previousStatus: volume,
                requestedLevel: level,
                writeSucceeded: false
            )
            return
        }

        let writeSucceeded = onSetVolume(level)
        feedbackInteraction.recordVolumeUpdate(
            previousStatus: volume,
            requestedLevel: level,
            writeSucceeded: writeSucceeded
        )
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            beginSliderInteractionIfNeeded()
            return
        }
        guard feedbackInteraction.endEditing() else { return }
        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }

    private func beginSliderInteractionIfNeeded() {
        feedbackInteraction.beginEditing(previousStatus: volume) {
            onSetMuted(false)
        }
    }

    private func handleUserMuteChange() {
        let writeSucceeded = onSetMuted(!volume.isMuted)
        guard feedbackInteraction.shouldPlayForUnmute(
            previousStatus: volume,
            writeSucceeded: writeSucceeded
        ) else { return }

        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }
}
