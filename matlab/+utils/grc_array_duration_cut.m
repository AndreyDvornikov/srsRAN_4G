function [cut_complex_vec] = grc_array_duration_cut(complex_vec, samplerate, duration_ms)
%GRC_ARRAY_DURATION_CUT Summary of this function goes here
%   Detailed explanation goes here
arguments (Input)
    complex_vec
    samplerate
    duration_ms
end

arguments (Output)
    cut_complex_vec
end

n_samples = floor(duration_ms / 1000 * samplerate);
n_samples = min(n_samples, length(complex_vec));


cut_complex_vec = complex_vec(1:n_samples);

end