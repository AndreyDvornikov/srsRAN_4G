filepath = "./large/srsENB_signal_time_domain_6_prb.dat";

% LTE Grid configuration
CONST_N_PRB = 6;
CONST_SUBCARRIERS_SPACING = 15e3; % это база

switch CONST_N_PRB
    case 6
        samplerate = 1.92e6;  % Гц        fft_size = 128;
        n_window_size = fft_size;
        overlap = round(n_window_size * 0.75); % 75% перекрытие
    case 15
        samplerate = 3.84e6;
        fft_size = 256;
        n_window_size = fft_size;
        overlap = round(n_window_size * 0.75);
    otherwise
        error('Неизвестное значение PRB');
end

signalFeatureExtractor

complex_vec = utils.grc_file_read(filepath, samplerate);
complex_vec = utils.grc_array_duration_cut(complex_vec, samplerate, 50);

tic;
[S, F, T] = spectrogram(complex_vec, n_window_size, overlap, fft_size, samplerate, 'centered');
elapsed = toc;
fprintf('Готово за %.2f сек\n', elapsed);

S_dB = 10*log10(abs(S).^2 + eps);

figure;
imagesc(T*1000, F/1e6, S_dB); % время в мс, частота в МГц
axis xy;

xlabel('Время (мс)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Частота (МГц)', 'FontSize', 13, 'FontWeight', 'bold');
title(sprintf('LTE %d PRB - 2D Waterfall', CONST_N_PRB), 'FontSize', 15, 'FontWeight', 'bold');

colormap(jet);
c = colorbar;
c.Label.String = 'Мощность (дБ)';
c.Label.FontSize = 12;

clim([max(S_dB(:))-70, max(S_dB(:))]);

grid on;
set(gca, 'GridAlpha', 0.3, 'LineWidth', 1);

% Детали на панель
dim = [0.15 0.75 0.35 0.15];
str = {
    sprintf('FFT: %d (подходит для %d PRB)', fft_size, CONST_N_PRB),
    sprintf('Разрешение по частоте: %.2f кГц', (samplerate/fft_size)/1e3),
    sprintf('Разрешение по времени: %.2f мкс', (n_window_size - overlap)/samplerate*1e6),
    sprintf('Активных поднесущих: %d', 12*CONST_N_PRB),
    sprintf('Полезная полоса: %.2f МГц', (12*CONST_N_PRB*15)/1000)
};
annotation('textbox', dim, 'String', str, 'FitBoxToText', 'on', ...
           'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);
