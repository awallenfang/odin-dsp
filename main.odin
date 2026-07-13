package odin_dsp

import "./transform"
import "./filter"
import "./generate"

import "core:math"
import "core:math/rand"
import "base:runtime"
import ma "vendor:miniaudio"

UserData :: struct {
    phase: f32,
    sr: f32,
    filter_state: ^filter.SimperSinSVFState(f32),
    osc_state: ^generate.SimpleOscillatorState(f32),
    freq: f32
}

dataCallback :: proc "cdecl" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
    context = runtime.default_context()
    
    out_ptr := ([^]f32)(pOutput)
    data := (^UserData)(pDevice.pUserData)
    filter_state := data.filter_state
    osc_state := data.osc_state
    freq :f32 = 400.
    phase_step := (2. * math.PI * freq) / data.sr
    generate.osc_note_on(data.osc_state, 0, data.freq)
    for i in 0..<frameCount {
        sample := generate.osc_tick(osc_state, 1./data.sr)
        out_ptr[i] = filter.tick_sample(filter_state, sample)
        data.phase += phase_step
        
        if data.phase > 2.0 * math.PI {
            data.phase -= 2.0 * math.PI
        }
    }
    data.freq += 1.
}

main :: proc() {
    filter_state: filter.SimperSinSVFState(f32)
    filter_state.mode = .Low
    filter.init(&filter_state, 48000.)
    filter.set_cutoff(&filter_state, 200.)
    filter.set_res(&filter_state, 0.8)

    osc_state: generate.SimpleOscillatorState(f32)
    generate.osc_init(&osc_state, 48000., 10)
    osc_state.type = .Square

    generate.osc_note_on(&osc_state, 1, 440.)
    generate.osc_note_on(&osc_state, 2, 140.)

    my_data := new(UserData)
    my_data.phase = 0.0
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

    ma.device_start(&device)

    for {}

}
