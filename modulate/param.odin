package modulate
import "base:intrinsics"

ModParam :: struct($T: typeid) where intrinsics.type_is_float(T) {
    base:  T,
    mod:   T,
    min:   T,
    max:   T,
    default: T,
}

param_init :: proc(p: ^ModParam($T), base: T, min: T, max: T, default: T) {
    p.mod = 0.
    p.base = clamp(base, min, max)
    p.min = min
    p.max = max
    p.default = clamp(default, min, max)
}

param_set :: proc(p: ^ModParam($T), base: T) {
    p.base = clamp(base, p.min, p.max)
}

param_get :: proc(p: ^ModParam($T)) -> T {
    return p.base + p.mod
}

param_reset :: proc(p: ^ModParam($T), base: T) {
    p.base = p.default
}
