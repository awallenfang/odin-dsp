package filter

import "core:math"
import "base:intrinsics"

BiquadMode :: enum {
    Lowpass,
    Highpass,
    Bandpass, 
    Notch,
    Peak, 
}

init_biquad :: proc{
    init_biquad_df1,
    init_biquad_tdf2
}

set_cutoff_biquad :: proc{
    set_cutoff_biquad_df1,
    set_cutoff_biquad_tdf2,
}
set_q_biquad :: proc{
    set_q_biquad_df1,
    set_q_biquad_tdf2,
}
set_mode_biquad :: proc{
    set_mode_biquad_df1,
    set_mode_biquad_tdf2,
}
set_peak_gain_biquad :: proc{
    set_peak_gain_biquad_df1,
    set_peak_gain_biquad_tdf2,
}
set_sample_rate_biquad :: proc{
    set_sample_rate_biquad_df1,
    set_sample_rate_biquad_tdf2,
}
tick_sample_biquad :: proc{
    tick_sample_biquad_df1,
    tick_sample_biquad_tdf2
}

BiquadFilterState :: union($T: typeid) {
    BiquadFilterStateDF1(T),
    BiquadFilterStateTDF2(T),
}


BiquadFilterStateDF1 :: struct($T: typeid) where intrinsics.type_is_float(T) {
    x1:          T,
    x2:          T,
    y1:          T,
    y2:          T,

    cutoff:      T,
    sample_rate: T,
    q:           T,
    peak_gain:   T,

    b0:          T,
    b1:          T,
    b2:          T,
    a1:          T,
    a2:          T,

    mode:        BiquadMode,
}

init_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), sample_rate: T) {
    state.x1 = 0.
    state.x2 = 0.
    state.y1 = 0.
    state.y2 = 0.
    
    state.sample_rate = sample_rate
    state.peak_gain = 1.0 
    
    state.mode = .Lowpass

    set_q_biquad_df1(state, 0.707)      
    set_cutoff_biquad_df1(state, 1000.0)
}

set_cutoff_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), cutoff: T) {
    max_safe_cutoff := (state.sample_rate / 2.) - 10.0
    state.cutoff = math.clamp(cutoff, 10.0, max_safe_cutoff)
    reinit_biquad_df1(state)
}

set_q_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), q: T) {
    state.q = math.clamp(q, 0.1, 100.0)
    reinit_biquad_df1(state)
}

set_mode_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), mode: BiquadMode) {
    state.mode = mode
    reinit_biquad_df1(state)
}

set_peak_gain_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), linear_gain: T) {
    state.peak_gain = math.max(linear_gain, 0.001) 
    if state.mode == .Peak {
        reinit_biquad_df1(state)
    }
}

set_sample_rate_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), sample_rate: T) {
    state.sample_rate = sample_rate
    reinit_biquad_df1(state)
}

tick_sample_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T), sample: T) -> T {
    output := (state.b0 * sample) + 
              (state.b1 * state.x1) + 
              (state.b2 * state.x2) - 
              (state.a1 * state.y1) - 
              (state.a2 * state.y2)

    state.x2 = state.x1
    state.x1 = sample
    
    state.y2 = state.y1
    state.y1 = output

    return output
}

@(private)
reinit_biquad_df1 :: proc(state: ^BiquadFilterStateDF1($T)) {
    // https://webaudio.github.io/Audio-EQ-Cookbook/audio-eq-cookbook.html
    w0 := 2.0 * T(math.PI) * (state.cutoff / state.sample_rate)
    cos_w0 := math.cos(w0)
    sin_w0 := math.sin(w0)
    
    alpha := sin_w0 / (2.0 * state.q)

    b0, b1, b2, a0, a1, a2: T

    switch state.mode {
        case .Lowpass:
            b0 = (1.0 - cos_w0) / 2.0
            b1 =  1.0 - cos_w0
            b2 = (1.0 - cos_w0) / 2.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Highpass:
            b0 = (1.0 + cos_w0) / 2.0
            b1 = -(1.0 + cos_w0)
            b2 = (1.0 + cos_w0) / 2.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Bandpass:
            b0 =  alpha
            b1 =  0.0
            b2 = -alpha
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Notch:
            b0 =  1.0
            b1 = -2.0 * cos_w0
            b2 =  1.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha
            
        case .Peak:
            A := math.sqrt(state.peak_gain)
            
            b0 =  1.0 + alpha * A
            b1 = -2.0 * cos_w0
            b2 =  1.0 - alpha * A
            a0 =  1.0 + alpha / A
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha / A
    }

    // Normalization
    a0_inv := 1.0 / a0
    state.b0 = b0 * a0_inv
    state.b1 = b1 * a0_inv
    state.b2 = b2 * a0_inv
    state.a1 = a1 * a0_inv
    state.a2 = a2 * a0_inv
}



BiquadFilterStateTDF2 :: struct($T: typeid) where intrinsics.type_is_float(T) {
    x1:          T,
    x2:          T,
    y1:          T,
    y2:          T,

    cutoff:      T,
    sample_rate: T,
    q:           T,
    peak_gain:   T,

    b0:          T,
    b1:          T,
    b2:          T,
    a1:          T,
    a2:          T,

    mode:        BiquadMode,
}

init_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), sample_rate: T) {
    state.x1 = 0.
    state.x2 = 0.
    state.y1 = 0.
    state.y2 = 0.
    
    state.sample_rate = sample_rate
    state.peak_gain = 1.0 
    
    state.mode = .Lowpass

    set_q_biquad_tdf2(state, 0.707)      
    set_cutoff_biquad_tdf2(state, 1000.0)
}

set_cutoff_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), cutoff: T) {
    max_safe_cutoff := (state.sample_rate / 2.) - 10.0
    state.cutoff = math.clamp(cutoff, 10.0, max_safe_cutoff)
    reinit_biquad_tdf2(state)
}

set_q_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), q: T) {
    state.q = math.clamp(q, 0.1, 100.0)
    reinit_biquad_tdf2(state)
}

set_mode_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), mode: BiquadMode) {
    state.mode = mode
    reinit_biquad_tdf2(state)
}

set_peak_gain_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), linear_gain: T) {
    state.peak_gain = math.max(linear_gain, 0.001) 
    if state.mode == .Peak {
        reinit_biquad_tdf2(state)
    }
}

set_sample_rate_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), sample_rate: T) {
    state.sample_rate = sample_rate
    reinit_biquad_tdf2(state)
}

tick_sample_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T), sample: T) -> T {
    output := (state.b0 * sample) + 
              (state.b1 * state.x1) + 
              (state.b2 * state.x2) - 
              (state.a1 * state.y1) - 
              (state.a2 * state.y2)

    state.x2 = state.x1
    state.x1 = sample
    
    state.y2 = state.y1
    state.y1 = output

    return output
}

@(private)
reinit_biquad_tdf2 :: proc(state: ^BiquadFilterStateTDF2($T)) {
    // https://webaudio.github.io/Audio-EQ-Cookbook/audio-eq-cookbook.html
    w0 := 2.0 * T(math.PI) * (state.cutoff / state.sample_rate)
    cos_w0 := math.cos(w0)
    sin_w0 := math.sin(w0)
    
    alpha := sin_w0 / (2.0 * state.q)

    b0, b1, b2, a0, a1, a2: T

    switch state.mode {
        case .Lowpass:
            b0 = (1.0 - cos_w0) / 2.0
            b1 =  1.0 - cos_w0
            b2 = (1.0 - cos_w0) / 2.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Highpass:
            b0 = (1.0 + cos_w0) / 2.0
            b1 = -(1.0 + cos_w0)
            b2 = (1.0 + cos_w0) / 2.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Bandpass:
            b0 =  alpha
            b1 =  0.0
            b2 = -alpha
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha

        case .Notch:
            b0 =  1.0
            b1 = -2.0 * cos_w0
            b2 =  1.0
            a0 =  1.0 + alpha
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha
            
        case .Peak:
            A := math.sqrt(state.peak_gain)
            
            b0 =  1.0 + alpha * A
            b1 = -2.0 * cos_w0
            b2 =  1.0 - alpha * A
            a0 =  1.0 + alpha / A
            a1 = -2.0 * cos_w0
            a2 =  1.0 - alpha / A
    }

    // Normalization
    a0_inv := 1.0 / a0
    state.b0 = b0 * a0_inv
    state.b1 = b1 * a0_inv
    state.b2 = b2 * a0_inv
    state.a1 = a1 * a0_inv
    state.a2 = a2 * a0_inv
}