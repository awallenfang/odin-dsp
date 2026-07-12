package generate
import "core:math"
import "core:fmt"
import "base:intrinsics"

SimpleOscillatorMode :: enum {
    Sine,
    Square
}

Voice :: struct($T: typeid) {
    note_id:           int,
    phase:             T,
    current_frequency: T,
    target_frequency:  T,
    is_active:         bool,
}

SimpleOscillatorState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    type: SimpleOscillatorMode,
    sample_rate: f32,
    voices:      []Voice(T),
    glide_speed: T
}

osc_init :: proc(state: ^SimpleOscillatorState($T), sample_rate: f32, max_voices : int = 10) {
    state.sample_rate = sample_rate
    state.type = .Sine
    state.glide_speed = 20.0 
    
    state.voices = make([]Voice(T), max_voices)
}

osc_tick :: proc(state: ^SimpleOscillatorState($T), dt: T) -> T {
    out: T = 0.0
    active_count := 0
    
    for &v in state.voices {
        if !v.is_active && v.current_frequency == 0.0 do continue
        
        if v.is_active {
            v.current_frequency += (v.target_frequency - v.current_frequency) * state.glide_speed * dt
        } else {
            v.current_frequency = 0.0 
        }

        if v.current_frequency <= 0.0 do continue
        active_count += 1

        out += 0.3 * math.sin(v.phase)
        
        phase_step := (2.0 * math.PI * v.current_frequency) / state.sample_rate
        v.phase += phase_step
        if v.phase > 2.0 * math.PI {
            v.phase -= 2.0 * math.PI
        }
    }
    
    if active_count > 1 {
        out /= T(active_count)
    }
    
    return out
}

osc_cleanup :: proc(state: ^SimpleOscillatorState($T)) {
    delete(state.voices)
}

osc_note_on :: proc(state: ^SimpleOscillatorState($T), note_id: int, freq: T) {
    for &v in state.voices {
        if v.is_active && v.note_id == note_id {
            v.target_frequency = freq
            return
        }
    }

    for &v in state.voices {
        if !v.is_active {
            v.note_id = note_id
            v.target_frequency = freq
            if v.current_frequency == 0.0 {
                v.current_frequency = freq 
            }
            v.phase = 0.0
            v.is_active = true
            return
        }
    }
    
}

osc_note_off :: proc(state: ^SimpleOscillatorState($T), note_id: int) {
    for &v in state.voices {
        if v.is_active && v.note_id == note_id {
            v.is_active = false
            }
    }
}