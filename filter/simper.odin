package filter

import "core:time"
import "core:math"
import "base:intrinsics"

/*
###### Simper SVF filters ######
Sin and tan implementation of Simper SVF filters
*/

SVFFilterMode :: enum {
    Low,
    Band,
    High,
    Notch,
    Peak,
}


SimperFilterState :: union($T: typeid) {
    SimperTanSVFState(T),
    SimperSinSVFState(T),
}

SimperTanSVFState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    ic1eq:       T,
    ic2eq:       T,
    cutoff:      T,
    sample_rate: f32,
    g:           T,
    res:         T,
    k:           T,
    a1:          T,
    a2:          T,
    mode:        SVFFilterMode,
}

init_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), sample_rate: f32) {
    state.ic1eq = 0.
    state.ic2eq = 0.
    state.sample_rate = sample_rate
    state.mode = .Low

    set_res_simper_tan_svf(state, 0.2)
    set_cutoff_simper_tan_svf(state, 1000.0) // Safe initial frequency
}

set_cutoff_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), cutoff: T) {
    max_safe_cutoff := (state.sample_rate / 2.) - 10.0
    state.cutoff = math.clamp(cutoff, 10.0, max_safe_cutoff)
    reinit_simper_tan_svf(state)
}

set_res_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), res: T) {
    state.res = math.clamp(res, 0.0, 0.99)
    reinit_simper_tan_svf(state)
}

set_sample_rate_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), sample_rate: T) {
    state.sample_rate = sample_rate
    reinit_simper_tan_svf(state)
}

@(private)
tick_sample_full_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), sample: T) -> (T, T, T) {
    v1 := state.a1 * state.ic1eq + state.a2 * (sample - state.ic2eq)
    v2 := state.ic2eq + state.g * v1

    state.ic1eq = 2. * v1 - state.ic1eq
    state.ic2eq = 2. * v2 - state.ic2eq

    low := v2
    band := v1
    high := sample - state.k * v1 - v2

    return low, band, high
}

tick_sample_simper_tan_svf :: proc(state: ^SimperTanSVFState($T), sample: T) -> T {
    low, band, high := tick_sample_full_simper_tan_svf(state, sample)
    
    switch state.mode {
        case .Low:   return low
        case .Band:  return band
        case .High:  return high
        case .Notch: return low + high
        case .Peak:  return low - high 
    }
    return 0.
}

@(private)
reinit_simper_tan_svf :: proc(state: ^SimperTanSVFState($T)) {
    state.g = math.tan(math.PI * state.cutoff / state.sample_rate)
    
    q := 1.0 / (2.0 * (1.0 - state.res))
    state.k = 1.0 / q

    state.a1 = 1. / (1. + state.g * state.k + state.g * state.g)
    state.a2 = state.g * state.a1
}


SimperSinSVFState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    res:         T,
    cutoff:      T,
    sample_rate: f32,
    ic1eq:       T,
    ic2eq:       T,
    k:           T,
    g0:          T,
    g1:          T,
    g2:          T,
    mode:        SVFFilterMode,
}

init_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), sample_rate: f32) {
    state.ic1eq = 0.0
    state.ic2eq = 0.0
    state.sample_rate = sample_rate
    state.mode = .Low

    set_res_simper_sin_svf(state, 0.2)
    set_cutoff_simper_sin_svf(state, 500.0)
}

set_cutoff_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), cutoff: T) {
    max_safe_cutoff := (state.sample_rate / 2.0) - 10.0
    state.cutoff = math.clamp(cutoff, 10.0, max_safe_cutoff)
    reinit_simper_sin_svf(state)
}

set_sample_rate_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), sample_rate: T) {
    state.sample_rate = sample_rate
    reinit_simper_sin_svf(state)
}

set_res_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), res: T) {
    state.res = math.clamp(res, 0.0, 1.0)
    reinit_simper_sin_svf(state)
}

set_mode_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), mode: SVFFilterMode) {
    state.mode = mode
}

@(private)
reinit_simper_sin_svf :: proc(state: ^SimperSinSVFState($T)) {
    w := math.PI * state.cutoff / state.sample_rate

    state.k = 2.0 - 1.45 * state.res

    s1 := math.sin(w)
    s2 := math.sin(2.0 * w)

    nrm := 1.0 / (2.0 + state.k * s2)

    state.g0 = s2 * nrm
    state.g1 = (-2.0 * s1 * s1 - state.k * s2) * nrm
    state.g2 = (2.0 * s1 * s1) * nrm
}

tick_sample_full_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), sample: T) -> (low: T, band: T, high: T) {
    t0 := sample - state.ic2eq
    t1 := state.g0 * t0 + state.g1 * state.ic1eq
    t2 := state.g2 * t0 + state.g0 * state.ic1eq
    v1 := t1 + state.ic1eq
    v2 := t2 + state.ic2eq

    state.ic1eq += 2.0 * t1
    state.ic2eq += 2.0 * t2

    high = sample - state.k * v1 - v2
    band = v1
    low = v2
    return
}

tick_sample_simper_sin_svf :: proc(state: ^SimperSinSVFState($T), sample: T) -> T {
    low, band, high := tick_sample_full_simper_sin_svf(state, sample)
    
    switch state.mode {
        case .Low:   return low
        case .Band:  return band
        case .High:  return high
        case .Notch: return low + high
        case .Peak:  return low - high
    }
    return 0.0
}

/*
###### Simper 1-Pole ######
1-Pole filter for parameter smoothing
*/
SimperOnePoleState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    s: T,
    g: T,
    G: T,
    sample_rate: T,
    time: T,
}

init_one_pole :: proc(state: ^SimperOnePoleState($T), sample_rate: T, time: T) {
    state.s = 0.0
    state.sample_rate = sample_rate
    set_smoothing_time_one_pole(state, 0.01)
}

set_smoothing_time_one_pole :: proc(state: ^SimperOnePoleState($T), time: T) {
    state.time = math.max(time, 0.0001)
    
    cutoff := 1.0 / (2.0 * T(math.PI) * state.time)
    
    max_safe_cutoff := (state.sample_rate / 2.0) - 10.0
    cutoff = math.clamp(cutoff, 0.1, max_safe_cutoff)
    
    state.g = math.tan(T(math.PI) * cutoff / state.sample_rate)
    state.G = state.g / (1.0 + state.g)
}

set_sample_rate_one_pole :: proc(state: ^SimperOnePoleState($T), sample_rate: T) {
    state.sample_rate = sample_rate
    set_smoothing_time_one_pole(state, state.time)
}

tick_sample_one_pole :: proc(state: ^SimperOnePoleState($T), target: T) -> T {
    v := (target - state.s) * state.G
    
    output := v + state.s
    
    state.s = output + v 
    
    return output
}

snap_to_value_one_pole :: proc(state: ^SimperOnePoleState($T), value: T) {
    state.s = value
}