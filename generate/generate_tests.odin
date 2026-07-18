package generate

import "core:math"
import "core:testing"
import "../modulate"

@test
test_osc_init_and_cleanup :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 48000, 4)
	defer osc_cleanup(&s)

	testing.expectf(t, len(s.voices) == 4, "expected 4 voices got %d", len(s.voices))
	testing.expectf(t, s.sample_rate == 48000, "expected 48000 got %v", s.sample_rate)
}

@test
test_osc_sine_output :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 4800, 1, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)
	s.type = .Sine

	osc_note_on(&s, 0, 440)
	mx, mn: f32
	for _ in 0..<4800 {
		v := osc_tick(&s, 1.0 / 4800)
		mx = max(mx, v)
		mn = min(mn, v)
	}
	testing.expectf(t, mx > 0.5, "sine max too low: %v", mx)
	testing.expectf(t, mn < -0.5, "sine min too high: %v", mn)
	osc_note_off(&s, 0)
}

@test
test_osc_square_output :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 4800, 1, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)
	s.type = .Square

	osc_note_on(&s, 0, 440)
	mx, mn: f32
	for _ in 0..<4800 {
		v := osc_tick(&s, 1.0 / 4800)
		mx = max(mx, v)
		mn = min(mn, v)
	}
	testing.expectf(t, abs(mx - 1.0) < 0.2, "square max expected ~1.0 got %v", mx)
	testing.expectf(t, abs(mn + 1.0) < 0.2, "square min expected ~-1.0 got %v", mn)
	osc_note_off(&s, 0)
}

@test
test_osc_sawtooth_output :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 4800, 1, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)
	s.type = .Sawtooth

	osc_note_on(&s, 0, 440)
	mx, mn: f32
	for _ in 0..<4800 {
		v := osc_tick(&s, 1.0 / 4800)
		mx = max(mx, v)
		mn = min(mn, v)
	}
	testing.expectf(t, mx > 0.5, "saw max too low: %v", mx)
	testing.expectf(t, mn < -0.5, "saw min too high: %v", mn)
	osc_note_off(&s, 0)
}

@test
test_osc_triangle_output :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 4800, 1, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)
	s.type = .Triangle

	osc_note_on(&s, 0, 440)
	mx, mn: f32
	for _ in 0..<4800 {
		v := osc_tick(&s, 1.0 / 4800)
		mx = max(mx, v)
		mn = min(mn, v)
	}
	testing.expectf(t, mx > 0.5, "tri max too low: %v", mx)
	testing.expectf(t, mn < -0.5, "tri min too high: %v", mn)
	osc_note_off(&s, 0)
}

@test
test_osc_note_off_releases :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 100, 1, glide_speed = 0, glide = 0, sustain_gain = 0.0)
	defer osc_cleanup(&s)

	osc_note_on(&s, 0, 440)

	for _ in 0..<200 { osc_tick(&s, 1.0 / 100) }
	osc_note_off(&s, 0)

	for _ in 0..<500 { osc_tick(&s, 1.0 / 100) }
	testing.expectf(t, !s.voices[0].is_active,
		"voice should be inactive after release, phase=%v val=%v", s.voices[0].adsr.phase, s.voices[0].adsr.current_val)
}

@test
test_osc_voice_stealing :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 1000, 2, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)

	osc_note_on(&s, 0, 440)
	osc_note_on(&s, 1, 880)
	// Both voices active
	active := s.voices[0].is_active && s.voices[1].is_active
	testing.expectf(t, active, "expected 2 active voices")
}

@test
test_osc_detune :: proc(t: ^testing.T) {
	s: SimpleOscillatorState(f32)
	osc_init(&s, 1000, 1, glide_speed = 0, glide = 0, sustain_gain = 1.0)
	defer osc_cleanup(&s)

	modulate.param_set(&s.detune, 1.0)
	osc_note_on(&s, 0, 440)
	for _ in 0..<100 { osc_tick(&s, 1.0 / 1000) }
	_ = s.voices[0].current_frequency
}

@test
test_polyblep :: proc(t: ^testing.T) {
	v := polyblep(f32(0.01), f32(0.05))
	testing.expectf(t, v < 0, "polyblep at 0.01 expected negative got %v", v)

	v = polyblep(f32(0.5), f32(0.05))
	testing.expectf(t, v == 0, "polyblep at 0.5 expected 0 got %v", v)

	v = polyblep(f32(0.98), f32(0.05))
	testing.expectf(t, v > 0, "polyblep near 1 expected positive got %v", v)
}
