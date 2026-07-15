package filter

import "core:math"
import "base:intrinsics"

MoogMode :: enum {
    Low6,
    Low12,
    Low18, 
    Low24,
}

MoogFilterState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    s1:          T,
    s2:          T,
    s3:          T,
    s4:          T,
    
    cutoff:      T,
    sample_rate: T,
    res:         T,
    
    g:           T,
    G:           T,
    k:           T, 
    
    mode:        MoogMode,
}

init_moog :: proc(state: ^MoogFilterState($T), sample_rate: T) {
    state.s1 = 0.
    state.s2 = 0.
    state.s3 = 0.
    state.s4 = 0.
    
    state.sample_rate = sample_rate
    state.mode = .Low24

    set_res_moog(state, 0.2)
    set_cutoff_moog(state, 1000.0) 
}

set_cutoff_moog :: proc(state: ^MoogFilterState($T), cutoff: T) {
    max_safe_cutoff := (state.sample_rate / 2.) - 10.0
    state.cutoff = math.clamp(cutoff, 10.0, max_safe_cutoff)
    reinit_moog(state)
}

set_res_moog :: proc(state: ^MoogFilterState($T), res: T) {
    state.res = math.clamp(res, 0.0, 1.0)
    reinit_moog(state)
}

set_sample_rate_moog :: proc(state: ^MoogFilterState($T), sample_rate: T) {
    state.sample_rate = sample_rate
    reinit_moog(state)
}

@(private)
tick_sample_full_moog :: proc(state: ^MoogFilterState($T), sample: T) -> (T, T, T, T) {
    S1 := state.s1 / (1. + state.g)
    S2 := state.s2 / (1. + state.g)
    S3 := state.s3 / (1. + state.g)
    S4 := state.s4 / (1. + state.g)
    
    // Resolve feedback loop
    S_sigma := S4 + (state.G * S3) + (state.G * state.G * S2) + (state.G * state.G * state.G * S1)
    G4 := state.G * state.G * state.G * state.G
    u := (sample - state.k * S_sigma) / (1. + state.k * G4)

    // Process poles
    v1 := (u - state.s1) * state.G
    y1 := v1 + state.s1
    state.s1 = y1 + v1

    v2 := (y1 - state.s2) * state.G
    y2 := v2 + state.s2
    state.s2 = y2 + v2

    v3 := (y2 - state.s3) * state.G
    y3 := v3 + state.s3
    state.s3 = y3 + v3

    v4 := (y3 - state.s4) * state.G
    y4 := v4 + state.s4
    state.s4 = y4 + v4

    return y1, y2, y3, y4
}

@(private)
reinit_moog :: proc(state: ^MoogFilterState($T)) {
    state.g = math.tan(math.PI * state.cutoff / state.sample_rate)
    
    state.G = state.g / (1. + state.g)

    state.k = state.res * 4.0 
}

tick_sample_moog :: proc(state: ^MoogFilterState($T), sample: T) -> T {
    y1, y2, y3, y4 := tick_sample_full_moog(state, sample)
    
    switch state.mode {
        case .Low6: return y1
        case .Low12: return y2
        case .Low18: return y3
        case .Low24: return y4
    }
    return 0.
}