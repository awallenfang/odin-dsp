package modulate

import "core:fmt"
import "base:intrinsics"

ADSRPhase :: enum {
    Idle,
    Attack,
    Decay,
    Sustain,
    Release,
}

ADSRType :: enum {
    Linear
}
ADSRState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    attack_t:     T,
    decay_t:      T,
    sustain_t:    T,
    release_t:    T,
    
    peak_gain:    T,
    sustain_gain: T,

    current_val:  T,
    phase:        ADSRPhase,
    
    active_release_rate: T,
    type:         ADSRType,

    sample_rate: T
}

adsr_setup :: proc(
    state: ^ADSRState($T), 
    attack: T, 
    decay: T, 
    release: T, 
    peak_gain: T,
    sustain_gain: T,
    sample_rate: T
) {
    state.attack_t     = attack
    state.decay_t      = decay
    state.release_t    = release
    state.peak_gain    = peak_gain
    state.sustain_gain = sustain_gain
    state.phase        = .Idle
    state.current_val  = 0.0
    state.sample_rate  = sample_rate
}

adsr_note_on :: proc(state: ^ADSRState($T)) {
    state.phase = .Attack
}

adsr_note_off :: proc(state: ^ADSRState($T)) {
    state.phase = .Release
    
    if state.release_t > 0 {
        state.active_release_rate = state.current_val / state.release_t
    }
}

tick_sample_adsr :: proc(state: ^ADSRState($T)) -> T {
    dt := 1. / state.sample_rate
    switch state.phase {
    case .Idle:
        state.current_val = 0.0
    case .Attack:
        if state.attack_t > 0 {
            rate := state.peak_gain / state.attack_t
            state.current_val += rate * dt
        } else {
            state.current_val = state.peak_gain
        }
        
        if state.current_val >= state.peak_gain {
            state.current_val = state.peak_gain
            state.phase = .Decay
        }
    case .Decay:
        if state.decay_t > 0 {
            rate := (state.peak_gain - state.sustain_gain) / state.decay_t
            state.current_val -= rate * dt
        } else {
            state.current_val = state.sustain_gain
        }
        
        if state.current_val <= state.sustain_gain {
            state.current_val = state.sustain_gain
            state.phase = .Sustain
        }

    case .Sustain:
        state.current_val = state.sustain_gain
    case .Release:
        if state.release_t > 0 {
            state.current_val -= state.active_release_rate * dt
        } else {
            state.current_val = 0.0
        }
        
        if state.current_val <= 0.0 {
            state.current_val = 0.0
            state.phase = .Idle
        }
    }
    return state.current_val
}

