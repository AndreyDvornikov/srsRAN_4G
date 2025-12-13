clc; clear;

complex_pss_u_idx_list  = [25,29,34];
complex_pss_vectors     = zeros(62, length(complex_pss_u_idx_list), "like", 1+1i);

for u_idx=1:length(complex_pss_u_idx_list)
    u = complex_pss_u_idx_list(u_idx);
    complex_pss_vectors(:, u_idx) = pss_sss.generate_pss(u);
end

seq_n_id_1 = pss_sss.generate_pss(25);

complex_pss_vectors_conj = conj(complex_pss_vectors);

u_idx = 1;

pss_sequence = complex_pss_vectors(:, u_idx);
pss_seq_conj = complex_pss_vectors_conj(:, u_idx);
maxlag       = length(pss_sequence) - 1;

dfft_scale_size = 1024;

pss_seq_1_spectre = fftshift(fft(complex_pss_vectors(:, 1), dfft_scale_size, 1)); 
pss_seq_2_spectre = fftshift(fft(complex_pss_vectors(:, 2), dfft_scale_size, 1)); 
pss_seq_3_spectre = fftshift(fft(complex_pss_vectors(:, 3), dfft_scale_size, 1)); 

figure("Name", "pss spectre"); 

x_bins = -dfft_scale_size/2:dfft_scale_size/2-1;
subplot(2,1,1);
plot(x_bins, abs(pss_seq_1_spectre), 'Color', '#FFFF00', 'LineWidth', 1.2, 'DisplayName', 'PSS 0');
hold on;
plot(x_bins, abs(pss_seq_2_spectre), 'LineStyle', '--', 'Color', '#7B68EE', 'LineWidth', 1.2, 'DisplayName', 'PSS 1');
plot(x_bins, abs(pss_seq_3_spectre), 'LineStyle', ':', 'Color', '#00FFFF', 'LineWidth', 1.2, 'DisplayName', 'PSS 2');
hold off;

xlabel('Bin_{fft}');
ylabel('abs(FFT)');
title('Спектры PSS');
legend('Location', 'best', 'FontSize', 12);
grid on;

subplot(2,1,2);
plot(x_bins, angle(pss_seq_1_spectre), 'Color', '#FFFF00', 'LineWidth', 1.2, 'DisplayName', 'PSS 0');
hold on;
plot(x_bins, angle(pss_seq_2_spectre), 'LineStyle', '--', 'Color', '#7B68EE', 'LineWidth', 1.2, 'DisplayName', 'PSS 1');
plot(x_bins, angle(pss_seq_3_spectre), 'LineStyle', ':', 'Color', '#00FFFF', 'LineWidth', 1.2, 'DisplayName', 'PSS 2');
hold off;

xlabel('Bin_{fft}');
ylabel('angle(FFT)');
title('Фазы PSS');
legend('Location', 'best', 'FontSize', 12);
grid on;

psd_estimate = abs(pss_seq_1_spectre).^2 / (length(pss_sequence) * dfft_scale_size);

figure('Name', 'Спектральное распределение PSS');
histogram(psd_estimate, 'Normalization', 'probability', "NumBins", 64);
xlabel('Уровень мощности (дБ)');
ylabel('Вероятность');
title('Распределение спектральной плотности мощности PSS');

% calc complex crosscorr
% R_s1s1 - корреляциия между sequence1 и sequence1 PSS
[R_s1s1, lags1] = xcorr(pss_sequence, maxlag, "normalized");
R_s1s2 = xcorr(pss_sequence, complex_pss_vectors(:, 2), maxlag, "normalized"); 
R_s1s3 = xcorr(pss_sequence, complex_pss_vectors(:, 3), maxlag, "normalized");

figure("Name", "xcorr step 1'"); 

subplot(2,1,1)
stem(lags1, abs(R_s1s1), "Color", "#FFFF00", "Marker", "+", "DisplayName", "abs(CCF(pss_{1}(t), pss_{1}(t + \tau)))"); hold on;
stem(lags1, abs(R_s1s2), "Color", "#7B68EE", "Marker", "x", "DisplayName", "abs(CCF(pss_{1}(t), pss_{2}(t + \tau)))"); 
stem(lags1, abs(R_s1s3), "Color", "#00FFFF", "Marker", "*", "DisplayName", "abs(CCF(pss_{1}(t), pss_{3}(t + \tau)))"); hold off;
xlabel('\tau');
ylabel('abs(xcorr)');
grid on;
legend("FontSize", 14, "Location", "best");

subplot(2,1,2)
stem(lags1, angle(R_s1s1), "Color", "#FFFF00", "Marker", "+", "DisplayName", "arg(CCF(pss_{1}(t), pss_{1}(t + \tau)))"); hold on;
stem(lags1, angle(R_s1s2), "Color", "#7B68EE", "Marker", "x", "DisplayName", "arg(CCF(pss_{1}(t), pss_{2}(t + \tau)))"); 
stem(lags1, angle(R_s1s3), "Color", "#00FFFF", "Marker", "*", "DisplayName", "arg(CCF(pss_{1}(t), pss_{3}(t + \tau)))"); hold off;
xlabel('\tau');
ylabel('angle(xcorr)');
grid on;
legend("FontSize", 14, "Location", "best");

W_s1s1_n_fft = length(R_s1s1);
W_s1s1 = fftshift(fft(R_s1s1, W_s1s1_n_fft));

figure; 
plot( ...
    -W_s1s1_n_fft/2:W_s1s1_n_fft/2-1, abs(W_s1s1) ...
);
grid on;
legend;

% подумать над квантованием последовательности до разрядноси АЦП
% pss эта [-1;1] - единичная окружность
test_pss1 = pss_sequence;
test_pss1_qant = complex_pss_vectors_conj(:, u_idx) * 10000;


% добавляем шума

% N = length(pss_sequence);
% 
% proc_buffer = zeros(3*N, 1, 'like', 1+1i);
% proc_buffer(N+1:2*N) = pss_sequence;
% 
% % Опорный сигнал для matched filter
% ref_signal = pss_seq_conj;
% 
% % Лаги от -N до 2*N
% lags = -N:2*N;
% 
% % Предвычисляем корреляцию для всех лагов
% matched_corr = zeros(size(lags));
% for i = 1:length(lags)
%     lag = lags(i);
% 
%     % Создаём буфер для опорного сигнала со сдвигом
%     pss_conj_buffer = zeros(3*N, 1, 'like', 1+1i);
% 
%     % Размещаем flip(pss_conj) со сдвигом lag
%     for idx = 1:N
%         buffer_idx = N + 1 + lag + (idx - 1);
%         if buffer_idx >= 1 && buffer_idx <= 3*N
%             pss_conj_buffer(buffer_idx) = ref_signal(idx);
%         end
%     end
% 
%     % Корреляция
%     matched_corr(i) = abs(sum(proc_buffer .* pss_conj_buffer));
% end
% 
% % График 1: Общая корреляция
% figure('Name', 'Matched filter корреляция');
% stem(lags, matched_corr, 'filled');
% hold on;
% [max_val, max_idx] = max(matched_corr);
% plot([lags(max_idx), lags(max_idx)], [0, max_val], 'r--', 'LineWidth', 1);
% xlabel('lag');
% ylabel('|xcorr|');
% title(sprintf('Matched filter корреляция (макс при lag=%d)', lags(max_idx)));
% grid on;
% hold off;
% 
% % График 2: Интерактивный с эффектом схлопывания
% fig = figure('Name', 'ЛЧМ коррелятор - эффект схлопывания', 'Position', [100, 100, 1200, 700]);
% ax1 = axes('Parent', fig, 'Position', [0.1, 0.55, 0.85, 0.35]);
% ax2 = axes('Parent', fig, 'Position', [0.1, 0.15, 0.85, 0.35]);
% 
% current_lag = 0;
% 
% function update_plot(ax1, ax2, proc_buffer, ref_signal, matched_corr, lags, current_lag, N)
%     % Создаём буфер для опорного сигнала со сдвигом
%     pss_conj_buffer = zeros(3*N, 1, 'like', 1+1i);
% 
%     % Размещаем flip(pss_conj) со сдвигом lag
%     for idx = 1:N
%         buffer_idx = N + 1 + current_lag + (idx - 1);
%         if buffer_idx >= 1 && buffer_idx <= 3*N
%             pss_conj_buffer(buffer_idx) = ref_signal(idx);
%         end
%     end
% 
%     % Z × Z*(сдвинутое)
%     time_product = proc_buffer .* pss_conj_buffer;
% 
%     % Спектр
%     spectrum_of_product = fftshift(fft(time_product));
%     freqs = (-(3*N-1)/2:(3*N-1)/2);
% 
%     % Верхний график: СПЕКТР Z × Z*
%     cla(ax1);
%     stem(ax1, freqs, abs(spectrum_of_product), 'filled', 'b');
%     xlabel(ax1, 'freq');
%     ylabel(ax1, '|FFT|');
%     title(ax1, sprintf('Lag = %d', current_lag));
%     grid(ax1, 'on');
%     ylim(ax1, [0, max(abs(spectrum_of_product))*1.1]);
%     xlim(ax1, [min(freqs), max(freqs)]);
% 
%     hold(ax1, 'on');
%     plot(ax1, [0, 0], [0, max(abs(spectrum_of_product))], 'r--', 'LineWidth', 1);
%     hold(ax1, 'off');
% 
%     % Нижний график: корреляция
%     cla(ax2);
%     hold(ax2, 'on');
% 
%     stem(ax2, lags, matched_corr, 'filled', 'Color', [0.7 0.7 0.7]);
% 
%     lag_idx = find(lags == current_lag);
%     current_corr_value = matched_corr(lag_idx);
% 
%     stem(ax2, current_lag, current_corr_value, 'r', 'filled', 'LineWidth', 2, 'MarkerSize', 10);
%     plot(ax2, [current_lag, current_lag], [0, max(matched_corr)], 'r--', 'LineWidth', 2);
% 
%     xlabel(ax2, 'lag');
%     ylabel(ax2, '|xcorr|');
%     title(ax2, sprintf('|xcorr| = %.2f', current_corr_value));
% 
%     xlim(ax2, [min(lags), max(lags)]);
%     ylim(ax2, [0, max(matched_corr)*1.1]);
%     grid(ax2, 'on');
%     hold(ax2, 'off');
% 
%     drawnow;
% end
% 
% slider = uicontrol('Parent', fig, 'Style', 'slider', ...
%     'Position', [100, 50, 900, 30], ...
%     'Min', -N, 'Max', 2*N, 'Value', current_lag, ...
%     'SliderStep', [1/(3*N), 10/(3*N)]);
% 
% lag_text = uicontrol('Parent', fig, 'Style', 'text', ...
%     'Position', [500, 80, 200, 30], ...
%     'String', sprintf('Lag: %d', current_lag), ...
%     'FontSize', 12, 'FontWeight', 'bold');
% 
% set(slider, 'Callback', @(src, event) slider_callback(src, ax1, ax2, proc_buffer, ref_signal, matched_corr, lags, lag_text, N));
% 
% function slider_callback(src, ax1, ax2, proc_buffer, ref_signal, matched_corr, lags, lag_text, N)
%     current_lag = round(get(src, 'Value'));
%     set(lag_text, 'String', sprintf('Lag: %d', current_lag));
% 
%     if abs(current_lag) < 5
%         set(lag_text, 'ForegroundColor', [1 0 0]);
%     else
%         set(lag_text, 'ForegroundColor', [0 0 0]);
%     end
% 
%     update_plot(ax1, ax2, proc_buffer, ref_signal, matched_corr, lags, current_lag, N);
% end
% 
% update_plot(ax1, ax2, proc_buffer, ref_signal, matched_corr, lags, current_lag, N);