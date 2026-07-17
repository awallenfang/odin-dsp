package modulate

ModSource :: union($T: typeid) #no_nil {
    ^LFOState(T),
    ^ADSRState(T)
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
}

matrix_add_adsr :: proc(m: ^ModulationMatrix($T), adsr: ^ADSRState(T)) -> int {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(adsr))
    return idx
}

matrix_add_lfo :: proc(m: ^ModulationMatrix($T), lfo: ^LFOState(T)) -> int {
    idx := len(m.sources)
    append(&m.sources, ModSource(T)(lfo))
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

mod_source_value :: proc(source: ModSource($T)) -> T {
    switch s in source {
    case ^LFOState(T):  return tick_sample(s)
    case ^ADSRState(T): return tick_sample(s)
    }
    unreachable()
}

matrix_tick :: proc(m: ^ModulationMatrix($T)) {
    for &route in m.routes {
        val := mod_source_value(m.sources[route.source_idx])
        target := m.targets[route.target_idx]

        if !route.bipolar && val < 0 {
            val = 0
        }
        val *= route.depth

        target.mod = val
    }
}

matrix_cleanup :: proc(m: ^ModulationMatrix($T)) {
    delete(m.sources)
    delete(m.targets)
    delete(m.routes)
}
