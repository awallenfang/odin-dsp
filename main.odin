package odin_dsp

import "./transform"
import "./filter"
import "./generate"
import "core:time"
import "base:runtime"
import ma "vendor:miniaudio"

UserData :: struct {
    sr: f32,
    // filter_state: ^filter.SimperSinSVFState(f32),
    filter_state: ^filter.MoogFilterState(f32),
    osc_state: ^generate.SimpleOscillatorState(f32),
}

dataCallback :: proc "cdecl" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
    context = runtime.default_context()
    
    out_ptr := ([^]f32)(pOutput)
    data := (^UserData)(pDevice.pUserData)
    filter_state := data.filter_state
    osc_state := data.osc_state
    for i in 0..<frameCount {
        sample := generate.osc_tick(osc_state, 1./data.sr)
        out_ptr[i] = 0.3 * filter.tick_sample(filter_state, sample)
    }
}

main :: proc() {
    filter_state: filter.MoogFilterState(f32)
    filter_state.mode = .Lowpass24
    filter.init(&filter_state, 48000.)
    filter.set_cutoff(&filter_state, 1000.)
    filter.set_res(&filter_state, 0.3)
    
    osc_state: generate.SimpleOscillatorState(f32)
    generate.osc_init(&osc_state, 48000., 10)
    osc_state.type = .Square
    osc_state.glide_speed = 1000

    my_data := new(UserData)
    my_data.sr = 48000.0
    my_data.filter_state = &filter_state
    my_data.osc_state = &osc_state
    defer free(my_data)
    device_config := ma.device_config_init(ma.device_type.playback)
    device_config.playback.format = ma.format.f32
    device_config.playback.channels = 1
    device_config.sampleRate = 48000
    device_config.dataCallback = dataCallback
    device_config.pUserData = my_data

    device: ma.device
    result := ma.device_init(nil, &device_config, &device)
    if result != ma.result.SUCCESS {
        return
    }

    ma.device_start(&device)

    progression := [4][4]f32{
        {261.63, 329.63, 392.00, 493.88}, // Cmaj7
        {220.00, 261.63, 329.63, 392.00}, // Am7  
        {174.61, 220.00, 261.63, 329.63}, // Fmaj7 
        {196.00, 246.94, 293.66, 349.23}, // G7 
    }

    chord_idx := 0
    note_idx  := 0
    notes_played_in_current_chord := 0

    for {
        current_chord := progression[chord_idx]
        freq := current_chord[note_idx]
        
        generate.osc_note_on(&osc_state, note_idx, freq)
        
        time.sleep(250 * time.Millisecond)
        
        generate.osc_note_off(&osc_state, note_idx) 
        
        note_idx = (note_idx + 1) % len(current_chord)
        notes_played_in_current_chord += 1

        if notes_played_in_current_chord >= 16 {
            notes_played_in_current_chord = 0
            note_idx = 0 
            chord_idx = (chord_idx + 1) % len(progression) 
        }
    }

}
