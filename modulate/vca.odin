package modulate

import "base:intrinsics"

VCAState :: struct($T: typeid) where intrinsics.type_is_float(T) {
    gain: ModParam(T)
}

