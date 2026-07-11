package main

import "core:fmt"
import "core:math"
import ma "vendor:miniaudio"

UserData :: struct {
    phase: f32,
    sr: f32
}
dataCallback :: proc "cdecl" (pDevice: ^ma.device, pOutput, pInput: rawptr, frameCount: u32) {
    out_ptr := ([^]f32)(pOutput)
    data := (^UserData)(pDevice.pUserData)
    freq :f32 = 400.
    phase_step := (2. * math.PI * freq) / data.sr
    for i in 0..<frameCount {
        out_ptr[i] = math.sin(data.phase)
        data.phase += phase_step

        if data.phase > 2.0 * math.PI {
            data.phase -= 2.0 * math.PI
        }
    }
}


main :: proc() {
    my_data := new(UserData)
    my_data.phase = 0.0
    my_data.sr = 48000.0
    defer free(my_data)
    device_config := ma.device_config_init(ma.device_type.playback)
    device_config.playback.format = ma.format.f32
    device_config.playback.channels = 1
    device_config.sampleRate = 48000
    device_config.dataCallback = dataCallback
    device_config.pUserData = my_data

    device:ma.device
    result := ma.device_init(nil, &device_config, &device)

    ma.device_start(&device)

    for {}

    // engine_config := ma.engine_config_init()
    // engine_config.channels = AUDIO_CHANNELS
    // engine_config.sampleRate = AUDIO_SAMPLE_RATE
    // engine_config.listenerCount = 1

    // engine_init_result := ma.engine_init(&engine_config, &engine)
    // if engine_init_result != .SUCCESS {
    //     fmt.panicf("Failed to init miniaudio engine: %v", engine_init_result)
    // }
    // engine_start_result := ma.engine_start(&engine)
    // if engine_start_result != .SUCCESS {
    //     fmt.panicf("Failed to start miniaudio engine: %v", engine_start_result)
    // }

    // ma.engine_play_sound(&engine, "audio.mp3", nil)

    // for {}
}