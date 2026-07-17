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
    targets: [dynamic]^ModParam(T),
    routes:  [dynamic]ModRoute(T),
    cache:   [dynamic]T
}

matrix_add_adsr :: proc(m: ^ModulationMatrix($T), adsr: ^ADSRState(T)) -> int {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(adsr))
    append(&m.cache, T(0))
    return idx
}

matrix_add_lfo :: proc(m: ^ModulationMatrix($T), lfo: ^LFOState(T)) -> int {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(lfo))
    append(&m.cache, T(0))
    return idx
}

matrix_add_target :: proc(m: ^ModulationMatrix($T), target: ^ModParam(T)) -> int {
    idx := len(m.targets)
    append(&m.targets, target)
    return idx
}

matrix_add_route :: proc(m: ^ModulationMatrix($T), route: ModRoute(T)) -> int {
    idx := len(m.routes)
    append(&m.routes, route)
    return idx
}

matrix_tick :: proc(m: ^ModulationMatrix($T)) {
    for &route in m.routes {
        val: T
        switch source in m.sources[route.source_idx] {
            case ^LFOState(T):
                val = tick_sample(source)
            case ^ADSRState(T):
                val = tick_sample(source)
        }

        target := m.targets[route.target_idx]

        if route.bipolar {
            val *= route.depth
        } else {
            if val < 0 {
                val = 0
            }
            val *= route.depth
        }

        target.mod = val
    }
}

matrix_cleanup :: proc(m: ^ModulationMatrix($T)) {
    delete(m.sources)
    delete(m.targets)
    delete(m.routes)
    delete(m.cache)
}
