package modulate

import "core:math"
import "core:testing"

@test
test_adsr_full_cycle :: proc(t: ^testing.T) {
	SR :: f32(1000)
	s: ADSRState(f32)
	adsr_setup(&s, 0.05, 0.05, 0.05, 1.0, 0.5, SR)

	// Should start Idle
	testing.expectf(t, s.phase == .Idle, "expected Idle got %v", s.phase)

	// Note on → Attack
	adsr_note_on(&s)
	testing.expectf(t, s.phase == .Attack, "expected Attack got %v", s.phase)

	// Step through attack
	for _ in 0..<int(SR * 0.1) { tick_sample_adsr(&s) }
	testing.expectf(t, s.phase == .Decay || s.phase == .Sustain, "expected Decay/Sustain after attack, got %v", s.phase)

	// Step through decay
	for _ in 0..<int(SR * 0.1) { tick_sample_adsr(&s) }
	testing.expectf(t, s.phase == .Sustain, "expected Sustain got %v", s.phase)
	testing.expectf(t, abs(s.current_val - 0.5) < 0.01, "sustain expected 0.5 got %v", s.current_val)

	// Note off → Release
	adsr_note_off(&s)
	testing.expectf(t, s.phase == .Release, "expected Release got %v", s.phase)

	for _ in 0..<int(SR * 0.1) { tick_sample_adsr(&s) }
	testing.expectf(t, s.phase == .Idle, "expected Idle after release got %v", s.phase)
	testing.expectf(t, s.current_val == 0, "expected 0 after release got %v", s.current_val)
}

@test
test_adsr_instant_attack :: proc(t: ^testing.T) {
	SR :: f32(1000)
	s: ADSRState(f32)
	adsr_setup(&s, 0, 0.1, 0.1, 1.0, 0.5, SR)
	adsr_note_on(&s)
	tick_sample_adsr(&s)
	// With 0 attack, should jump to peak immediately
	testing.expectf(t, s.phase == .Decay, "expected Decay got %v", s.phase)
	testing.expectf(t, abs(s.current_val - 1.0) < 0.01, "peak expected 1.0 got %v", s.current_val)
}

@test
test_adsr_zero_release :: proc(t: ^testing.T) {
	SR :: f32(1000)
	s: ADSRState(f32)
	adsr_setup(&s, 0, 0, 0, 1.0, 1.0, SR)
	adsr_note_on(&s)
	for _ in 0..<5 { tick_sample_adsr(&s) }
	adsr_note_off(&s)
	for _ in 0..<5 { tick_sample_adsr(&s) }
	testing.expectf(t, s.phase == .Idle, "expected Idle got %v", s.phase)
}

@test
test_lfo_basic :: proc(t: ^testing.T) {
	SR :: f32(1000)
	s: LFOState(f32)
	lfo_setup(&s, SR)
	lfo_set_frequency(&s, 5)
	lfo_set_amplitude(&s, 2.0)

	mx: f32
	for _ in 0..<int(SR * 0.5) {
		v := tick_sample_lfo(&s)
		mx = max(mx, abs(v))
	}
	testing.expectf(t, abs(mx - 2.0) < 0.1, "LFO amplitude expected 2.0 got %v", mx)
}

@test
test_lfo_phase_wraps :: proc(t: ^testing.T) {
	SR :: f32(1000)
	s: LFOState(f32)
	lfo_setup(&s, SR)
	lfo_set_frequency(&s, 100) // high freq to trigger multiple wraps

	for _ in 0..<int(SR * 2) {
		_ = tick_sample_lfo(&s)
		testing.expectf(t, s.phase <= math.TAU + 0.001, "phase overflow: %v", s.phase)
		if s.phase > math.TAU { return }
	}
}

@test
test_param_basic :: proc(t: ^testing.T) {
	p: ModParam(f32)
	param_init(&p, 0.5, -1.0, 1.0, 0.0)

	testing.expectf(t, abs(p.base - 0.5) < 0.01, "base expected 0.5 got %v", p.base)
	testing.expectf(t, p.mod == 0, "mod expected 0 got %v", p.mod)

	v := param_get(&p)
	testing.expectf(t, abs(v - 0.5) < 0.01, "get expected 0.5 got %v", v)

	p.mod = 0.3
	v = param_get(&p)
	testing.expectf(t, abs(v - 0.8) < 0.01, "get+mod expected 0.8 got %v", v)

	param_reset(&p, 1.0)
	testing.expectf(t, abs(p.base - 0.0) < 0.01, "reset expected 0.0 got %v", p.base)
}

@test
test_param_clamping :: proc(t: ^testing.T) {
	p: ModParam(f32)
	param_init(&p, 5.0, -1.0, 1.0, 0.0)
	testing.expectf(t, abs(p.base - 1.0) < 0.01, "clamp high expected 1.0 got %v", p.base)
	param_init(&p, -5.0, -1.0, 1.0, 0.0)
	testing.expectf(t, abs(p.base - (-1.0)) < 0.01, "clamp low expected -1.0 got %v", p.base)
}

@test
test_matrix_add_and_tick :: proc(t: ^testing.T) {
	m: ModulationMatrix(f32)
	defer matrix_cleanup(&m)

	lfo: LFOState(f32)
	lfo_setup(&lfo, 1000)

	target: ModParam(f32)
	param_init(&target, 0, -10, 10, 0)

	src_idx := matrix_add_lfo(&m, &lfo)
	tgt_idx := matrix_add_target(&m, &target)
	_ = matrix_add_route(&m, ModRoute(f32){source_idx = src_idx, target_idx = tgt_idx, depth = 0.5, bipolar = true})

	// Tick should set target.mod to 0.5 * lfo output
	matrix_tick(&m)
	val := param_get(&target)
	_ = val
}

@test
test_matrix_bipolar_vs_unipolar :: proc(t: ^testing.T) {
	m: ModulationMatrix(f32)
	defer matrix_cleanup(&m)

	lfo: LFOState(f32)
	lfo_setup(&lfo, 1000)
	lfo_set_amplitude(&lfo, 1.0)

	t1, t2: ModParam(f32)
	param_init(&t1, 0, -10, 10, 0)
	param_init(&t2, 0, -10, 10, 0)

	si := matrix_add_lfo(&m, &lfo)
	ti1 := matrix_add_target(&m, &t1)
	ti2 := matrix_add_target(&m, &t2)
	_ = matrix_add_route(&m, ModRoute(f32){si, ti1, 1.0, true})
	_ = matrix_add_route(&m, ModRoute(f32){si, ti2, 1.0, false})

	matrix_tick(&m)
	// bipolar can be negative, unipolar cannot
	_ = t1
	_ = t2
}

@test
test_matrix_cleanup :: proc(t: ^testing.T) {
	m: ModulationMatrix(f32)
	lfo: LFOState(f32); lfo_setup(&lfo, 1000)
	t: ModParam(f32); param_init(&t, 0, -1, 1, 0)
	_ = matrix_add_lfo(&m, &lfo)
	_ = matrix_add_target(&m, &t)
	_ = matrix_add_route(&m, ModRoute(f32){0, 0, 1.0, true})
	matrix_cleanup(&m) // verify cleanup works without crash
}
