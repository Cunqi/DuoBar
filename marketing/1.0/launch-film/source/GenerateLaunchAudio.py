#!/usr/bin/env python3
"""Deterministically synthesize the original DuoBar 1.0 launch-film audio."""

from array import array
import math
from pathlib import Path
import random
import wave

SAMPLE_RATE = 48_000
DURATION = 20.5
FRAMES = int(SAMPLE_RATE * DURATION)
OUTPUT = Path.cwd() / "marketing/1.0/launch-film/audio"
TAU = math.tau


def smoothstep(edge0, edge1, value):
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def envelope(time, onset, attack, decay):
    age = time - onset
    if age < 0.0:
        return 0.0
    return smoothstep(0.0, attack, age) * math.exp(-max(0.0, age - attack) / decay)


def pan(sample, position):
    angle = (max(-1.0, min(1.0, position)) + 1.0) * math.pi / 4.0
    return sample * math.cos(angle), sample * math.sin(angle)


def int24_bytes(values):
    output = bytearray(len(values) * 3)
    cursor = 0
    for value in values:
        integer = int(max(-1.0, min(0.999999, value)) * 8_388_607)
        if integer < 0:
            integer += 1 << 24
        output[cursor] = integer & 0xFF
        output[cursor + 1] = (integer >> 8) & 0xFF
        output[cursor + 2] = (integer >> 16) & 0xFF
        cursor += 3
    return bytes(output)


def write_wave(path, left, right):
    interleaved = array("f")
    interleaved.extend(value for pair in zip(left, right) for value in pair)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(3)
        handle.setframerate(SAMPLE_RATE)
        chunk = 32_768
        for start in range(0, len(interleaved), chunk):
            handle.writeframesraw(int24_bytes(interleaved[start:start + chunk]))


def chord_at(time):
    # Open fifths and suspended tones avoid an overly sentimental cadence.
    if time < 6.0:
        return (73.416, 110.000, 164.814, 220.000)
    if time < 9.75:
        return (73.416, 123.471, 164.814, 246.942)
    if time < 14.25:
        return (82.407, 123.471, 184.997, 246.942)
    if time < 17.625:
        return (65.406, 98.000, 146.832, 220.000)
    return (73.416, 110.000, 146.832, 220.000)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    music_left = array("f", [0.0]) * FRAMES
    music_right = array("f", [0.0]) * FRAMES
    design_left = array("f", [0.0]) * FRAMES
    design_right = array("f", [0.0]) * FRAMES
    rng = random.Random(10_001)
    filtered_noise = 0.0

    beat_times = [3.0 + 0.75 * index for index in range(23)]
    visual_accents = [
        (0.75, 0.18, 92.0, -0.28),
        (3.0, 0.20, 196.0, 0.14),
        (4.5, 0.10, 740.0, -0.22),
        (4.875, 0.085, 820.0, -0.08),
        (5.25, 0.075, 900.0, 0.08),
        (5.625, 0.065, 980.0, 0.22),
        (6.0, 0.20, 146.8, 0.0),
        (9.0, 0.09, 660.0, 0.0),
        (9.75, 0.12, 330.0, -0.18),
        (10.875, 0.10, 392.0, 0.12),
        (12.0, 0.14, 880.0, 0.18),
        (13.125, 0.08, 440.0, -0.08),
        (15.75, 0.24, 110.0, 0.0),
        (17.625, 0.17, 220.0, 0.0),
        (19.125, 0.12, 293.7, 0.0),
    ]

    for index in range(FRAMES):
        time = index / SAMPLE_RATE
        fade_in = smoothstep(0.0, 2.2, time)
        fade_out = 1.0 - smoothstep(19.25, DURATION, time)
        frequencies = chord_at(time)

        pad = 0.0
        for partial, frequency in enumerate(frequencies):
            drift = 0.22 * math.sin(TAU * (0.031 + partial * 0.007) * time + partial)
            phase = TAU * frequency * time + drift
            pad += math.sin(phase) * (0.050 / (1.0 + partial * 0.42))
            pad += math.sin(phase * 2.003 + 0.7) * (0.009 / (partial + 1.0))
        air = math.sin(TAU * 293.665 * time + 0.45 * math.sin(TAU * 0.043 * time)) * 0.006

        pulse = 0.0
        if time >= 3.0:
            beat_index = int((time - 3.0) / 0.75)
            for candidate in (beat_index - 1, beat_index, beat_index + 1):
                if 0 <= candidate < len(beat_times):
                    onset = beat_times[candidate]
                    age = time - onset
                    if 0.0 <= age < 0.85:
                        env = envelope(time, onset, 0.022, 0.24)
                        base = 73.416 if candidate % 4 in (0, 3) else 110.0
                        pulse += env * (
                            math.sin(TAU * base * age) * 0.030
                            + math.sin(TAU * base * 2.01 * age + 0.3) * 0.010
                        )

        width = 0.012 * math.sin(TAU * 0.061 * time)
        music_left[index] = (pad + air + pulse + width) * fade_in * fade_out
        music_right[index] = (pad + air + pulse - width) * fade_in * fade_out

        raw_noise = rng.uniform(-1.0, 1.0)
        filtered_noise += 0.035 * (raw_noise - filtered_noise)
        left = 0.0
        right = 0.0
        for onset, strength, frequency, position in visual_accents:
            age = time - onset
            if 0.0 <= age < 1.1:
                attack = min(1.0, age / 0.012)
                decay = math.exp(-age / (0.16 if frequency > 500 else 0.38))
                tonal = math.sin(TAU * frequency * age + 0.16 * math.sin(TAU * 7.0 * age))
                noise_amount = filtered_noise * (0.20 if frequency > 500 else 0.06)
                sample = strength * attack * decay * (0.82 * tonal + noise_amount)
                panned_left, panned_right = pan(sample, position)
                left += panned_left
                right += panned_right
        design_left[index] = left * fade_out
        design_right[index] = right * fade_out

    mix_left = array("f", (music_left[i] * 0.94 + design_left[i] * 0.72 for i in range(FRAMES)))
    mix_right = array("f", (music_right[i] * 0.94 + design_right[i] * 0.72 for i in range(FRAMES)))
    peak = max(max(abs(value) for value in mix_left), max(abs(value) for value in mix_right))
    target_peak = 10 ** (-3.0 / 20.0)
    gain = target_peak / peak if peak else 1.0
    for index in range(FRAMES):
        mix_left[index] *= gain
        mix_right[index] *= gain

    write_wave(OUTPUT / "DuoBar-1.0-music.wav", music_left, music_right)
    write_wave(OUTPUT / "DuoBar-1.0-sound-design.wav", design_left, design_right)
    write_wave(OUTPUT / "DuoBar-1.0-final-mix.wav", mix_left, mix_right)
    achieved_peak = peak * gain
    print(
        f"sample_rate={SAMPLE_RATE} frames={FRAMES} duration={DURATION:.3f}s "
        f"gain={gain:.6f} peak={achieved_peak:.6f} ({20 * math.log10(achieved_peak):.2f} dBFS)"
    )


if __name__ == "__main__":
    main()
