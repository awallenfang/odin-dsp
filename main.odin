package odin_dsp

import "./transform"
import "./filter"
import "./generate"

import "base:runtime"
import ma "vendor:miniaudio"

UserData :: struct {
    sr: f32,
    // filter_state: ^filter.SimperSinSVFState(f32),
    filter_state: ^filter.BiquadFilterStateTDF2(f32),
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
        out_ptr[i] = filter.tick_sample(filter_state, sample)
    }
}

main :: proc() {
    // filter_state: filter.SimperSinSVFState(f32)
    // filter_state.mode = .Low
    // filter.init(&filter_state, 48000.)
    // filter.set_cutoff(&filter_state, 200.)
    // filter.set_res(&filter_state, 0.8)
    filter_state: filter.BiquadFilterStateTDF2(f32)
    filter_state.mode = .Lowpass
    filter.init_biquad(&filter_state, 48000.)
    filter.set_cutoff_biquad(&filter_state, 2000.)
    filter.set_q_biquad(&filter_state, 0.8)
    filter.set_mode_biquad(&filter_state, .Highpass)

    osc_state: generate.SimpleOscillatorState(f32)
    generate.osc_init(&osc_state, 48000., 10)
    osc_state.type = .Square

    generate.osc_note_on(&osc_state, 1, 440.)
    generate.osc_note_on(&osc_state, 2, 140.)

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

    for {}

}
