package transform
import "core:math"

@(private)
pad_signal_inplace :: proc(signal: ^[dynamic]complex32) {
    n := len(signal^)
    if n == 0 do return

    for _ in 0..<(math.next_power_of_two(n) - n) {
        append(signal, complex32(0+0i))
    }
}

// Basic adaptation of https://lloydroc.github.io/post/c/example-fft/
fft :: proc(signal: ^[dynamic]complex32) {
    // Pad to next power of 2
    pad_signal_inplace(signal)
    
    rearrange(signal)
    compute(signal)
}

ifft :: proc(signal: ^[dynamic]complex32, orig_len := 0) {

    rearrange(signal)
    compute(signal, inverse = true)

    if orig_len > 0 {
        resize(signal, orig_len)
    }
}

rearrange :: proc(signal: ^[dynamic]complex32) {
    target: uint = 0
    for position in 0..<uint(len(signal)) {
        if target > position {
            signal[target], signal[position] = signal[position], signal[target]
        }
        mask:uint= len(signal)
        for mask >>= 1; target & mask != 0; mask >>= 1 {
            target &= ~mask
        }
        target |= mask
    }
}

compute :: proc(signal: ^[dynamic]complex32, inverse := false) {
    for step:uint=1; step<len(signal); step <<= 1 {
        jump := step<<1
        step_d : f32 = f32(step)
        twiddle : complex32 = 1.
        for group in 0..<step {
            for pair := group; pair < len(signal); pair += jump {
                match := pair + step
                product := twiddle * signal[match]
                signal[match] = signal[pair] - product
                signal[pair] += product
            }
            if group+1 == step {
                continue
            }
            sign: f32 = 1.0 if inverse else -1.0
            angle := sign * math.PI * (f32(group + 1))/step_d
            twiddle = complex(math.cos(angle), math.sin(angle))
        }
    }
    if inverse {
        scaling_factor := 1.0 / f32(len(signal))
        for i in 0..<len(signal) {
            signal[i] *= complex(scaling_factor, 0.0)
        }
    }
}