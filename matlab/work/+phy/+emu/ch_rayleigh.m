% Канал с релеевскими замираниями
function y_t = ch_rayleigh(x_t)
    ch = comm.RayleighChannel();

    y_t = ch(x_t);
end 