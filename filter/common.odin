package filter
import "base:intrinsics"

FilterType :: enum {
    SimperSinSVF,
    SimperTanSVF,
    Moog,
    BiquadDF1,
    BiquadTDF2,
}

FilterState :: union($T: typeid) {
    SimperSinSVFState(T),
    SimperTanSVFState(T),
    MoogFilterState(T),
    BiquadFilterStateDF1(T),
    BiquadFilterStateTDF2(T),
}

init :: proc{
    init_biquad_df1,
    init_biquad_tdf2,
    init_moog,
    init_simper_sin_svf,
    init_simper_tan_svf,
    init_one_pole,
}

tick_sample :: proc {
    tick_sample_biquad_df1,
    tick_sample_biquad_tdf2,
    tick_sample_moog,
    tick_sample_simper_sin_svf,
    tick_sample_simper_tan_svf,
    tick_sample_one_pole
}

set_cutoff :: proc{
    set_cutoff_biquad_df1,
    set_cutoff_biquad_tdf2,
    set_cutoff_moog,
    set_cutoff_simper_sin_svf,
    set_cutoff_simper_tan_svf,
}

set_res :: proc {
    set_q_biquad_df1,
    set_q_biquad_tdf2,
    set_res_moog,
    set_res_simper_sin_svf,
    set_res_simper_tan_svf,
}

set_sample_rate :: proc {
    set_sample_rate_biquad_df1,
    set_sample_rate_biquad_tdf2,
    set_sample_rate_moog,
    set_sample_rate_simper_sin_svf,
    set_sample_rate_simper_tan_svf,
    set_sample_rate_one_pole

}

set_smoothing :: proc {
    set_smoothing_time_one_pole
}