package generate

SimpleOscillatorMode :: enum {
    Sine,
    Square
}

SimpleOscillatorState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    phase: T,
    type: SimpleOscillatorMode
}