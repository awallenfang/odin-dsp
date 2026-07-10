package odin_dsp

import "./transform"
import "core:math"

main :: proc() {
    n_bins := 2000
    signal := make([dynamic]complex32, n_bins)
    for i in 0..<n_bins {
        signal[i] = complex32(f32(i))
    }
    transform.fft(&signal)
}
