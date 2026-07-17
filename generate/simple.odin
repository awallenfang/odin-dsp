package generate
import "core:math"
import "core:fmt"
import "base:intrinsics"
import "../filter"
import "../modulate"

SimpleOscillatorMode :: enum {
    Sine,
    Square,
    Sawtooth,
    Triangle
}

Voice :: struct($T: typeid) {
    note_id:            int,
    phase:              T,
    current_frequency:  T,
    target_frequency:   T,
    is_active:          bool,
    adsr:               modulate.ADSRState(T),
    adsr_smoothing:     filter.SimperOnePoleState(T),
    filter:             filter.SimperSinSVFState(T)
}

SimpleOscillatorState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    type: SimpleOscillatorMode,
    sample_rate:    f32,
    voices:         []Voice(T),
    glide_speed:    modulate.ModParam(T),
    glide:          modulate.ModParam(T),

    attack:         modulate.ModParam(T),
    decay:          modulate.ModParam(T),
    release:        modulate.ModParam(T),
    peak_gain:      modulate.ModParam(T),
    sustain_gain:   modulate.ModParam(T),

    detune:         modulate.ModParam(T),

    cutoff:         modulate.ModParam(T),
    res:            modulate.ModParam(T),
    q:              modulate.ModParam(T),
    filter_peak_gain: modulate.ModParam(T),
}

osc_init :: proc(
    state: ^SimpleOscillatorState($T), 
    sample_rate: f32,
    max_voices : int = 10, 
    glide_speed := 20., 
    glide := 0.,
    attack := 0.001,
    decay := 0.5,
    release := 0.8,
    peak_gain:= 1.0,
    sustain_gain:= 0.0) {
    state.sample_rate = sample_rate
    state.type = .Square
    modulate.param_init(&state.glide_speed, T(glide_speed), 0., 100., 0.0)
    modulate.param_init(&state.glide, T(glide), 0., 1., 0.0)
    
    state.voices = make([]Voice(T), max_voices)
    modulate.param_init(&state.attack,T(attack), 0., 1000., 0.001)
    modulate.param_init(&state.decay, T(decay), 0., 1000., 1.0)
    modulate.param_init(&state.release, T(release), 0., 1000., 1.0)
    modulate.param_init(&state.peak_gain, T(peak_gain), 0., 1000., 0.5)
    modulate.param_init(&state.sustain_gain, T(sustain_gain), 0., 1000., 0.0)

    modulate.param_init(&state.detune, 0., -10., 10., 0.)
    modulate.param_init(&state.cutoff, T(1500.), 10., 24000., 0.1)
    modulate.param_init(&state.res, T(0.2), 0., 1., 0.1)
    modulate.param_init(&state.q, T(0.707), 0.1, 100., 0.707)
    modulate.param_init(&state.filter_peak_gain, T(1.0), 0.001, 1000., 1.0)
    for &voice in state.voices {
        smoother: filter.SimperOnePoleState(T)
        filter.init_one_pole(&smoother, state.sample_rate, 0.01)
        voice.adsr_smoothing = smoother
        filter.init(&voice.filter, state.sample_rate)
    }

    
}

osc_tick :: proc(state: ^SimpleOscillatorState($T), dt: T) -> T {
    out: T = 0.0
    active_count := 0
    
    for &v in state.voices {
        if !v.is_active && v.current_frequency == 0.0 do continue

        adsr_amp_unsmoothed := modulate.tick_sample(&v.adsr)
        adsr_amp := filter.tick_sample_one_pole(&v.adsr_smoothing, adsr_amp_unsmoothed)
        if v.adsr.phase == .Idle && adsr_amp < 0.0001 {
            v.is_active = false
            v.current_frequency = 0.0
            continue
        }
        
        if v.is_active {
            if T(modulate.param_get(&state.glide)) < 0.5 {
                v.current_frequency = v.target_frequency
            } else {
                v.current_frequency += (v.target_frequency - v.current_frequency) * T(modulate.param_get(&state.glide_speed)) * dt
            }
        } else {
            v.current_frequency = 0.0 
        }

        if v.current_frequency <= 0.0 do continue
        active_count += 1

        play_freq := v.current_frequency + T(modulate.param_get(&state.detune))
        if play_freq <= 0.0 do continue

        t := v.phase / math.TAU
        dt_norm := play_freq / T(state.sample_rate)

        voice_sample: T
        switch state.type {
            case .Sine:
                voice_sample = math.sin(v.phase) * adsr_amp
            case .Square:
                naive := t < 0.5 ? T(1.0) : T(-1.0)
                
                correction_0 := polyblep(t, dt_norm)
                
                t_half := t + 0.5
                if t_half >= 1.0 do t_half -= 1.0
                correction_half := polyblep(t_half, dt_norm)
                
                voice_sample = (naive + correction_0 - correction_half) * adsr_amp
            case .Sawtooth:
                naive := (2.0 * t) - 1.0
                
                voice_sample = (naive - polyblep(t, dt_norm)) * adsr_amp
            case .Triangle:
                voice_sample = (2.0 * abs(2.0 * (v.phase / math.TAU) - 1.0) - 1.0) * adsr_amp
            }

        f := &v.filter
        filter.set_cutoff_simper_sin_svf(f, T(modulate.param_get(&state.cutoff)))
        filter.set_res_simper_sin_svf(f, T(modulate.param_get(&state.res)))
        out += filter.tick_sample_simper_sin_svf(f, voice_sample)
        
        phase_step := (2.0 * math.PI * play_freq) / state.sample_rate
        v.phase += phase_step
        if v.phase > 2.0 * math.PI {
            v.phase -= 2.0 * math.PI
        }
    }
    
    return out
}

osc_cleanup :: proc(state: ^SimpleOscillatorState($T)) {
    delete(state.voices)
}

osc_note_on :: proc(state: ^SimpleOscillatorState($T), note_id: int, freq: T) {
    // Check for active voices
    for &v in state.voices {
        if v.is_active && v.note_id == note_id {
            v.target_frequency = freq
            modulate.adsr_setup(
                &v.adsr, 
                T(modulate.param_get(&state.attack)), 
                T(modulate.param_get(&state.decay)), 
                T(modulate.param_get(&state.release)), 
                T(modulate.param_get(&state.peak_gain)), 
                T(modulate.param_get(&state.sustain_gain)), 
                state.sample_rate)
            modulate.adsr_note_on(&v.adsr)
            return
        }
    }
    
    // If there isn't an active voice with this ID create a new one
    for &v in state.voices {
        if !v.is_active {
            v.note_id = note_id
            v.target_frequency = freq
            if v.current_frequency == 0.0 {
                v.current_frequency = freq 
            }
            v.phase = 0.0
            v.is_active = true

            filter.snap_to_value_one_pole(&v.adsr_smoothing, 0.0)

            modulate.adsr_setup(
                &v.adsr, 
                T(modulate.param_get(&state.attack)), 
                T(modulate.param_get(&state.decay)), 
                T(modulate.param_get(&state.release)), 
                T(modulate.param_get(&state.peak_gain)), 
                T(modulate.param_get(&state.sustain_gain)), 
                state.sample_rate)
            modulate.adsr_note_on(&v.adsr)
            return
        }
    }
    
}

osc_note_off :: proc(state: ^SimpleOscillatorState($T), note_id: int) {
    for &v in state.voices {
        if v.is_active && v.note_id == note_id {
                modulate.adsr_note_off(&v.adsr)
            }
    }
}

osc_set_attack :: proc(state: ^SimpleOscillatorState($T), attack: T) {
    state.attack = attack
}

osc_set_decay :: proc(state: ^SimpleOscillatorState($T), decay: T) {
    state.decay = decay
}

osc_set_release :: proc(state: ^SimpleOscillatorState($T), release: T) {
    state.release = release
}

osc_set_sustain_gain :: proc(state: ^SimpleOscillatorState($T), gain: T) {
    state.sustain_gain = gain
}

osc_set_peak_gain :: proc(state: ^SimpleOscillatorState($T), gain: T) {
    state.peak_gain = gain
}

osc_set_cutoff :: proc(state: ^SimpleOscillatorState($T), cutoff: T) {
    state.cutoff = cutoff
}

osc_set_res :: proc(state: ^SimpleOscillatorState($T), res: T) {
    state.res = res
}

osc_set_q :: proc(state: ^SimpleOscillatorState($T), q: T) {
    state.q = q
}

osc_set_filter_peak_gain :: proc(state: ^SimpleOscillatorState($T), gain: T) {
    state.filter_peak_gain = gain
}

@(private)
polyblep :: proc(t, dt: $T) -> T where intrinsics.type_is_float(T) {
    if t < dt {
        p := t / dt
        return p - 0.5 * p * p - 0.5
    } else if t > 1.0 - dt {
        p := (t - 1.0) / dt
        return 0.5 * p * p + p + 0.5
    }
    return 0.0
}