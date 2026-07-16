package modulate

ModSource :: union($T: typeid) {
    ^LFOState(T),
    ^ADSRState(T)
}

ModTarget :: struct($T: typeid) {
    data: rawptr,
    apply: proc(data: rawptr, raw_mod: T)
}

ModRoute :: struct($T: typeid) {
    source_idx: int,
    target_idx: int,
    depth: T,
    bipolar: bool
}

ModulationMatrix :: struct($T: typeid) {
    sources: [dynamic]ModSource(T),
    targets: [dynamic]ModTarget(T),
    routes: [dynamic]ModRoute(T),
    cache: [dynamic]T
}

matrix_add_adsr :: proc(m: ^ModulationMatrix($T), adsr: ^ADSRState(T)) {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(adsr))
    append(&m.cache, T(0))
    return idx
}
matrix_add_lfo :: proc(m: ^ModulationMatrix($T), lfo: ^LFOState(T)) {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(lfo))
    append(&m.cache, T(0))
    return idx

}

matrix_add_target :: proc(m: ^ModulationMatrix($T), target: ModTarget(T)) {
    idx := len(m.targets)
    append(&m.targets, target)
    return idx
}

matrix_tick :: proc(m: ^ModulationMatrix($T)) {
    for &route in m.routes {
        state
        val: T
        switch source in m.sources[route.source_idx] {
            case ^LFOState(T):
                state := (^LFOState(T))(source)
                val = modulate.tick_sample(state)
            case ^ADSRState(T):
                state := (^ADSRPhase(T))(source)
                val = modulate.tick_sample(state)
        }
        target := m.targets[route.target_idx]
        target.apply(target.rawptr, val)
    }
}