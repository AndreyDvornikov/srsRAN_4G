%% КОНФИГУРАЦИЯ
%{ 
  SA
  Первый (нулевой) сабфрейм:
  7678 - 9598 [1920]

  второй (первый) сабфрейм:
  9599 - 11519

  третий (второй) сабфрейм
  11519 - 13439

  четвёртый (третий) сабфрейм
  13439 - 15359

  пятый (четвёртый) сабфрейм
  15359 - 17279
%}

filepath = "./large/srsENB_signal_time_domain_6_prb.dat";

% LTE Grid configuration
CONST_N_PRB = 6;
CONST_SUBCARRIERS_SPACING = 15e3; % база

switch CONST_N_PRB
    case 6
        samplerate = 1.92e6;  % Гц
        fft_size = 128;
        n_window_size = (1/CONST_SUBCARRIERS_SPACING) * samplerate;
        overlap = round(n_window_size * 0); % 75% перекрытие
    case 15
        samplerate = 3.84e6;
        fft_size = 256;
        n_window_size = (1/CONST_SUBCARRIERS_SPACING) * samplerate;
        overlap = round(n_window_size * 0);
    otherwise
        error('Неизвестное значение PRB');
end

matFile = matfile(".\large\converted\srsENB_signal_time_domain_6_prb.dat.mat", "Writable", false);

duration_sec = 0.01;
num_samples = round(duration_sec * samplerate);

tic;
complex_vec2 = matFile.srs_signal_complex(1:num_samples, 1);  % Только часть!
ds_read_time = toc;
fprintf("Time read: %.2f\n", ds_read_time);

tic;
[S2, F2, T2] = spectrogram(complex_vec2, n_window_size, overlap, fft_size, samplerate, 'centered');
calc_time2 = toc;
fprintf('spectrogram tic-toc: %.2f сек\n', calc_time2);

S = S2; F = F2; T = T2;
S_dB = 10*log10(abs(S).^2 + eps);

figure('Position', [100 100 1200 800]);
imagesc(T*1000, F/1e6, S_dB);
axis xy;
xlabel('Время (мс)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Частота (МГц)', 'FontSize', 13, 'FontWeight', 'bold');
title(sprintf('LTE %d PRB - 2D Waterfall', CONST_N_PRB), ...
      'FontSize', 15, 'FontWeight', 'bold');
colormap(jet);
c = colorbar;
c.Label.String = 'Мощность (дБ)';
c.Label.FontSize = 12;
clim([max(S_dB(:))-70, max(S_dB(:))]);
grid on;
set(gca, 'GridAlpha', 0.3, 'LineWidth', 1);

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
