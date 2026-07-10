#+feature dynamic-literals
package transform

import "core:fmt"
import "core:math"
import "core:testing"

expect_close :: proc(t: ^testing.T, got, expected: []complex32, eps: f32 = 0.01, loc := #caller_location) {
	if !testing.expectf(t, len(got) == len(expected), "Length mismatch: got %d, expected %d", len(got), len(expected), loc = loc) {
		return
	}

	for i in 0..<len(got) {
		diff_re :f32= f32(math.abs(real(got[i]) - real(expected[i])))
		diff_im :f32= f32(math.abs(imag(got[i]) - imag(expected[i])))

		is_close := diff_re <= eps && diff_im <= eps

		if !is_close {
			testing.expectf(
				t,
				false, // Force fail since we already know it mismatched
				"\nElement mismatch at index %d:\nExpected: %v\nGot:      %v",
				i, expected, got,
				loc = loc,
			)
			return
		}
	}
}

@test
test_rearrange :: proc(t: ^testing.T) {
	signal := [dynamic]complex32{
		complex(1.0, 1.0), complex(2.0, 2.0), complex(3.0, 3.0), complex(4.0, 4.0),
		complex(5.0, 5.0), complex(6.0, 6.0), complex(7.0, 7.0), complex(8.0, 8.0),
	}
    defer delete(signal)
	expected := []complex32{
		complex(1.0, 1.0), complex(5.0, 5.0), complex(3.0, 3.0), complex(7.0, 7.0),
		complex(2.0, 2.0), complex(6.0, 6.0), complex(4.0, 4.0), complex(8.0, 8.0),
	}

	rearrange(&signal)
	expect_close(t, signal[:], expected)
    
}

@test
test_case_1 :: proc(t: ^testing.T) {
	signal := [dynamic]complex32{
		complex(0.0, 7.0), complex(1.0, 6.0), complex(2.0, 5.0), complex(3.0, 4.0),
		complex(4.0, 3.0), complex(5.0, 2.0), complex(6.0, 1.0), complex(7.0, 0.0),
	}
    defer delete(signal)
	expected := []complex32{
		complex(28.0, 28.0),   complex(5.656, 13.656), complex(0.0, 8.0),     complex(-2.343, 5.656),
		complex(-4.0, 4.0),    complex(-5.656, 2.343), complex(-8.0, 0.0),    complex(-13.656, -5.656),
	}

	fft(&signal)
	expect_close(t, signal[:], expected)
}

@test
test_case_2 :: proc(t: ^testing.T) {
	signal := [dynamic]complex32{
		complex(1.0, 1.0), complex(1.0, 1.0), complex(1.0, 1.0), complex(1.0, 1.0),
		complex(1.0, 1.0), complex(1.0, 1.0), complex(1.0, 1.0), complex(1.0, 1.0),
	}
    defer delete(signal)
	expected := []complex32{
		complex(8.0, 8.0), complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0),
		complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0),
	}

	fft(&signal)
	expect_close(t, signal[:], expected)
}

@test
test_case_3 :: proc(t: ^testing.T) {
	signal := [dynamic]complex32{
		complex(1.0, -1.0), complex(-1.0, 1.0), complex(1.0, -1.0), complex(-1.0, 1.0),
		complex(1.0, -1.0), complex(-1.0, 1.0), complex(1.0, -1.0), complex(-1.0, 1.0),
	}
    defer delete(signal)
	expected := []complex32{
		complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0),
		complex(8.0, -8.0), complex(0.0, 0.0), complex(0.0, 0.0), complex(0.0, 0.0),
	}

	fft(&signal)
	expect_close(t, signal[:], expected)
}

@test
test_case_4 :: proc(t: ^testing.T) {
	signal := [dynamic]complex32{
		complex(1.0, 0.0), complex(2.0, 0.0), complex(3.0, 0.0), complex(4.0, 0.0),
	}
    defer delete(signal)
	expected := []complex32{
		complex(10.0, 0.0), complex(-2.0, 2.0), complex(-2.0, 0.0), complex(-2.0, -2.0),
	}

	fft(&signal)
	expect_close(t, signal[:], expected)
}