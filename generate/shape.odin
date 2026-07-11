package generate

ADSRState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    attack: T,
    decay: T,
    sustain: T,
    release: T,
    sample_rate: f32,
    t: f32
}