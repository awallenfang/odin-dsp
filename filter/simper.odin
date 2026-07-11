package filter

import "core:math"

SVFFilterMode :: enum {
    Low,
    Band,
    High,
    Notch,
    Peak,
}

SimperTanSVF :: struct {
    ic1eq:       f32,
    ic2eq:       f32,
    cutoff:      f32,
    sample_rate: f32,
    g:           f32,
    res:         f32,
    k:           f32,
    a1:          f32,
    a2:          f32,
    mode:        SVFFilterMode,
}

init_simper_tan_svf :: proc(state: ^SimperTanSVF, sample_rate: f32) {
    state.ic1eq = 0.
    state.ic2eq = 0.

    state.sample_rate = sample_rate
    state.cutoff = sample_rate / 2.
    state.res = 0.2

    state.g = math.tan(math.PI * state.cutoff / state.sample_rate)
    state.k = 2. - 2. * state.res

    state.a1 = 1. / (1. + state.g * (state.g * state.k))
    state.a2 = state.g * state.a1

    state.mode = .Low
}

set_cutoff_simper_tan_svf :: proc(state: ^SimperTanSVF, cutoff: f32) {
    state.cutoff = cutoff
    reinit_simper_tan_svf(state)
}

set_res_simper_tan_svf :: proc(state: ^SimperTanSVF, res: f32) {
    state.res = res
    reinit_simper_tan_svf(state)
}

set_sample_rate_simper_tan_svf :: proc(state: ^SimperTanSVF, sample_rate: f32) {
    state.sample_rate = sample_rate
    reinit_simper_tan_svf(state)
}

@(private)
tick_sample_full_simper_tan_svf :: proc(state: ^SimperTanSVF, sample: f32) -> (f32, f32, f32) {
    v1 := state.a1 * state.ic1eq + state.a2 * (sample - state.ic2eq)
    v2 := state.ic2eq + state.g * v1

    state.ic1eq = 2. * v1 - state.ic1eq
    state.ic2eq = 2. * v2 - state.ic2eq

    low := v2
    band := v1
    high := sample - state.k * v1 - v2

    return low, band, high
}

tick_sample_simper_tan_svf :: proc(state: ^SimperTanSVF, sample: f32) -> f32 {
    low, band, high := tick_sample_full_simper_tan_svf(state, sample)
    
    switch state.mode {
        case .Low:   return low
        case .Band:  return band
        case .High:  return high
        case .Notch: return low + high
        case .Peak:  return low - high // Note: You might want (low - high) or something else depending on your peak implementation preference!
    }
    return 0.
}

@(private)
reinit_simper_tan_svf :: proc(state: ^SimperTanSVF) {
    state.g = math.tan(math.PI * state.cutoff / state.sample_rate)
    state.k = 2. - 2. * state.res

    state.a1 = 1. / (1. + state.g * (state.g * state.k))
    state.a2 = state.g * state.a1
}