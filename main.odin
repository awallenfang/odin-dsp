package odin_dsp

import "./transform"
import "./filter"
import "./generate"
import "./modulate"
import "core:time"
import "base:runtime"
import ma "vendor:miniaudio"
DEMO := 1

UserData :: struct {
    sr: f32,
    filter_state: ^filter.SimperSinSVFState(f32),
    osc_state: ^generate.SimpleOscillatorState(f32),
}

VibratoUserData :: struct {
    sr: f32,
    filter_state: ^filter.SimperSinSVFState(f32),
    osc_state: ^generate.SimpleOscillatorState(f32),
    mod_matrix: ^modulate.ModulationMatrix(f32),
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

dataCallbackVibrato :: proc "cdecl" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
    context = runtime.default_context()

    out_ptr := ([^]f32)(pOutput)
    data := (^VibratoUserData)(pDevice.pUserData)
    filter_state := data.filter_state
    osc_state := data.osc_state
    mod_matrix := data.mod_matrix
    for i in 0..<frameCount {
        modulate.matrix_tick(mod_matrix)
        sample := generate.osc_tick(osc_state, 1./data.sr)
        out_ptr[i] = 0.3 * filter.tick_sample(filter_state, sample)
    }
}

main :: proc() {
    if DEMO == 0 {
        filter_state: filter.SimperSinSVFState(f32)
        filter_state.mode = .Low
        filter.init(&filter_state, 48000.)
        filter.set_cutoff(&filter_state, 1500.)
        filter.set_res(&filter_state, 0.5)

        osc_state: generate.SimpleOscillatorState(f32)
        generate.osc_init(&osc_state, 48000., 10)
        osc_state.type = .Square
        osc_state.glide_speed = 10000

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

            if notes_played_in_current_chord == 0 {
                generate.osc_note_on(&osc_state, 5, freq / 2.)
            } else if notes_played_in_current_chord == 8 {
                generate.osc_note_on(&osc_state, 6, current_chord[note_idx+2] / 2.)
            }

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
    } else if DEMO == 1 {
        filter_state: filter.SimperSinSVFState(f32)
        filter_state.mode = .Low
        filter.init(&filter_state, 48000.)
        filter.set_cutoff(&filter_state, 1500.)
        filter.set_res(&filter_state, 0.5)

        osc_state: generate.SimpleOscillatorState(f32)
        generate.osc_init(&osc_state, 48000., 10)
        osc_state.type = .Square
        osc_state.glide_speed = 10000

        mod_matrix: modulate.ModulationMatrix(f32)
        lfo_state: modulate.LFOState(f32)
        modulate.lfo_setup(&lfo_state, 48000.)
        modulate.lfo_set_frequency(&lfo_state, 5.5)
        modulate.lfo_set_amplitude(&lfo_state, 5.0)

        _ = modulate.matrix_add_lfo(&mod_matrix, &lfo_state)
        _ = modulate.matrix_add_target(&mod_matrix, modulate.ModTarget(f32){
            data = &osc_state,
            apply = proc(data: rawptr, raw_mod: f32) {
                state := (^generate.SimpleOscillatorState(f32))(data)
                state.pitch_mod = raw_mod
            },
        })
        modulate.matrix_add_route(&mod_matrix, modulate.ModRoute(f32){
            source_idx = 0,
            target_idx = 0,
            depth      = 0.02,
            bipolar    = true,
        })

        my_data := new(VibratoUserData)
        my_data.sr = 48000.0
        my_data.filter_state = &filter_state
        my_data.osc_state = &osc_state
        my_data.mod_matrix = &mod_matrix
        defer free(my_data)

        device_config := ma.device_config_init(ma.device_type.playback)
        device_config.playback.format = ma.format.f32
        device_config.playback.channels = 1
        device_config.sampleRate = 48000
        device_config.dataCallback = dataCallbackVibrato
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

            if notes_played_in_current_chord == 0 {
                generate.osc_note_on(&osc_state, 5, freq / 2.)
            } else if notes_played_in_current_chord == 8 {
                generate.osc_note_on(&osc_state, 6, current_chord[note_idx+2] / 2.)
            }

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

        modulate.matrix_cleanup(&mod_matrix)
    }
}
