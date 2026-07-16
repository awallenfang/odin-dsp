package modulate

import "core:math"

LFOState :: struct($T: typeid) {
    phase:       T,
    frequency:   T,
    amplitude:   T,
    sample_rate: T,
}

lfo_setup :: proc(state: ^LFOState($T), sample_rate: T) {
    state.phase = 0
    state.frequency = 1.0
    state.amplitude = 1.0
    state.sample_rate = sample_rate
}

lfo_set_frequency :: proc(state: ^LFOState($T), freq: T) {
    state.frequency = freq
}

lfo_set_amplitude :: proc(state: ^LFOState($T), amp: T) {
    state.amplitude = amp
}

tick_sample_lfo :: proc(state: ^LFOState($T)) -> T {
    dt := 1.0 / state.sample_rate
    out := math.sin(state.phase) * state.amplitude
    state.phase += state.frequency * math.TAU * dt
    for state.phase > math.TAU {
        state.phase -= math.TAU
    }
    return out
}
