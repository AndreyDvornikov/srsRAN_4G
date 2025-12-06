% Исследование деградации корреляционного пика при фазовом вращении
% Демонстрация: амплитуда неизменна, но корреляция зависит от фазы

clc; clear; close all;

complex_pss_u_idx_list = [25, 29, 34];
N_pss = 62;  % Длина PSS последовательности
u_idx = 3;   % Выбираем u=34

complex_pss_vectors = zeros(N_pss, length(complex_pss_u_idx_list), 'like', 1+1i);

for idx = 1:length(complex_pss_u_idx_list)
    u = complex_pss_u_idx_list(idx);
    complex_pss_vectors(:, idx) = pss_sss.generate_pss(u);
end

pss_sequence = complex_pss_vectors(:, u_idx);

fprintf('Параметры PSS последовательности:\n');
fprintf('  Длина PSS: %d\n', N_pss);
fprintf('  Корень u: %d\n', complex_pss_u_idx_list(u_idx));
fprintf('  Средняя мощность: %.6f\n', mean(abs(pss_sequence).^2));
fprintf('  Тип: Zadoff-Chu (ZC) последовательность\n\n');

n_phase_points = 360;  % 1 deg шаг для высокого разрешения
phase_shift_rad = linspace(0, 2*pi, n_phase_points);
phase_shift_deg = phase_shift_rad * 180/pi;

n_trials = 200;
sigma_noise = 0.01;

peak_correlation_real = zeros(n_phase_points, 1);  % Реальная часть
peak_correlation_imag = zeros(n_phase_points, 1);  % Мнимая часть  
peak_correlation_abs = zeros(n_phase_points, 1);   % Модуль
peak_correlation_angle = zeros(n_phase_points, 1); % Фаза
signal_amplitude_mean = zeros(n_phase_points, 1);  % Средняя амплитуда
signal_power_mean = zeros(n_phase_points, 1);      % Средняя мощность

peak_correlation_abs_std = zeros(n_phase_points, 1);
signal_amplitude_std = zeros(n_phase_points, 1);

fprintf('phase points count: %d (step %.1f°)\n', n_phase_points, 360/n_phase_points);
fprintf('examples count: %d\n', n_trials);
fprintf('noise sigma: %.4f (SNR = %.1f dB)\n\n', ...
        sigma_noise, 10*log10(mean(abs(pss_sequence).^2)/sigma_noise^2));

tic;

for phase_idx = 1:n_phase_points
    phi = phase_shift_rad(phase_idx);

    phase_rotated_pss = pss_sequence * exp(1j * phi);

    peaks_abs_temp = zeros(n_trials, 1);
    peaks_real_temp = zeros(n_trials, 1);
    peaks_imag_temp = zeros(n_trials, 1);
    peaks_angle_temp = zeros(n_trials, 1);
    amplitude_temp = zeros(n_trials, 1);
    power_temp = zeros(n_trials, 1);

    noise_batch = sigma_noise/sqrt(2) * ...
                  (randn(N_pss, n_trials) + 1j*randn(N_pss, n_trials));

    for trial = 1:n_trials
        received_signal = phase_rotated_pss + noise_batch(:, trial);

        [R, lags] = xcorr(received_signal, pss_sequence, 'coeff');

        zero_lag_idx = (lags == 0);
        peak_complex = R(zero_lag_idx);

        peaks_abs_temp(trial) = abs(peak_complex);
        peaks_real_temp(trial) = real(peak_complex);
        peaks_imag_temp(trial) = imag(peak_complex);
        peaks_angle_temp(trial) = angle(peak_complex);

        amplitude_temp(trial) = mean(abs(received_signal));
        power_temp(trial) = mean(abs(received_signal).^2);
    end

    peak_correlation_abs(phase_idx) = mean(peaks_abs_temp);
    peak_correlation_abs_std(phase_idx) = std(peaks_abs_temp);
    peak_correlation_real(phase_idx) = mean(peaks_real_temp);
    peak_correlation_imag(phase_idx) = mean(peaks_imag_temp);
    peak_correlation_angle(phase_idx) = mean(peaks_angle_temp);
    signal_amplitude_mean(phase_idx) = mean(amplitude_temp);
    signal_amplitude_std(phase_idx) = std(amplitude_temp);
    signal_power_mean(phase_idx) = mean(power_temp);
end

elapsed_time = toc;
fprintf('\nМоделирование завершено за %.2f сек\n\n', elapsed_time);

peak_theory = cos(phase_shift_rad);

fprintf('=== РЕЗУЛЬТАТЫ ЭКСПЕРИМЕНТА ===\n\n');

% 1. Проверка постоянства амплитуды
amplitude_variation = std(signal_amplitude_mean) / mean(signal_amplitude_mean) * 100;
power_variation = std(signal_power_mean) / mean(signal_power_mean) * 100;

fprintf('1. ПОСТОЯНСТВО АМПЛИТУДЫ И МОЩНОСТИ:\n');
fprintf('   Средняя амплитуда: %.6f ± %.6f\n', ...
        mean(signal_amplitude_mean), std(signal_amplitude_mean));
fprintf('   Вариация амплитуды: %.4f%%\n', amplitude_variation);
fprintf('   Средняя мощность: %.6f ± %.6f\n', ...
        mean(signal_power_mean), std(signal_power_mean));
fprintf('   Вариация мощности: %.4f%%\n\n', power_variation);

% 2. Деградация корреляции
[min_corr, min_idx] = min(peak_correlation_abs);
[max_corr, max_idx] = max(peak_correlation_abs);

fprintf('2. ДЕГРАДАЦИЯ КОРРЕЛЯЦИОННОГО ПИКА:\n');
fprintf('   Максимум: %.6f при φ = %.1f°\n', max_corr, phase_shift_deg(max_idx));
fprintf('   Минимум: %.6f при φ = %.1f° (теория: π = 180°)\n', ...
        min_corr, phase_shift_deg(min_idx));
fprintf('   Динамический диапазон: %.2f дБ\n', 20*log10(max_corr/min_corr));

% 4. Характерные точки
[~, idx_90deg] = min(abs(phase_shift_deg - 90));
[~, idx_180deg] = min(abs(phase_shift_deg - 180));
[~, idx_270deg] = min(abs(phase_shift_deg - 270));

figure('Name', 'Эксперимент 2: Влияние фазового сдвига PSS', ...
       'Position', [100, 100, 1600, 1000]);

% График 1: Деградация корреляционного пика
subplot(3,3,1);
plot(phase_shift_deg, peak_correlation_abs, 'b-', 'LineWidth', 2);
hold on;
plot(phase_shift_deg, abs(peak_theory), 'r--', 'LineWidth', 1.5);
plot([0 360], [0 0], 'k:', 'LineWidth', 1);
scatter([0, 90, 180, 270, 360], ...
        [peak_correlation_abs(1), peak_correlation_abs(idx_90deg), ...
         peak_correlation_abs(idx_180deg), peak_correlation_abs(idx_270deg), ...
         peak_correlation_abs(end)], ...
        100, 'filled', 'MarkerEdgeColor', 'k');
hold off;
xlabel('Фазовый сдвиг \phi (deg)');
ylabel('|R(0)|');
title('Деградация пика корреляции');
legend('Эксперимент', 'Теория: |cos(φ)|', 'Location', 'south');
grid on;
xlim([0 360]);
ylim([-0.1 1.1]);
set(gca, 'XTick', 0:45:360);

% График 2: Постоянство амплитуды сигнала
subplot(3,3,2);
plot(phase_shift_deg, signal_amplitude_mean, 'g-', 'LineWidth', 2);
hold on;
fill([phase_shift_deg, fliplr(phase_shift_deg)], ...
     [signal_amplitude_mean + signal_amplitude_std; ...
      flipud(signal_amplitude_mean - signal_amplitude_std)], ...
     'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
yline(mean(signal_amplitude_mean), 'r--', 'LineWidth', 1.5, ...
      'Label', sprintf('Среднее: %.4f', mean(signal_amplitude_mean)));
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('Средняя амплитуда');
title('Постоянство амплитуды');
grid on;
xlim([0 360]);

% График 3: Постоянство мощности
subplot(3,3,3);
plot(phase_shift_deg, signal_power_mean, 'm-', 'LineWidth', 2);
hold on;
yline(mean(signal_power_mean), 'r--', 'LineWidth', 1.5, ...
      'Label', sprintf('Среднее: %.4f', mean(signal_power_mean)));
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('Средняя мощность');
title('Постоянство мощности');
grid on;
xlim([0 360]);

% График 4: Комплексная плоскость корреляции
subplot(3,3,4);
plot(peak_correlation_real, peak_correlation_imag, 'b-', 'LineWidth', 2);
hold on;
% Теоретическая окружность
theta_circle = linspace(0, 2*pi, 1000);
plot(cos(theta_circle), sin(theta_circle), 'r--', 'LineWidth', 1);
plot(0, 0, 'k+', 'MarkerSize', 15, 'LineWidth', 2);
% Отмечаем ключевые точки
scatter(peak_correlation_real([1, idx_90deg, idx_180deg, idx_270deg]), ...
        peak_correlation_imag([1, idx_90deg, idx_180deg, idx_270deg]), ...
        100, 'filled');
hold off;
xlabel('Re[R(0)]');
ylabel('Im[R(0)]');
title('Комплексная плоскость');
legend('Траектория', 'Единичная окружность', 'Location', 'best');
grid on;
axis equal;
xlim([-1.2 1.2]);
ylim([-1.2 1.2]);

% График 5: Реальная часть корреляции
subplot(3,3,5);
plot(phase_shift_deg, peak_correlation_real, 'b-', 'LineWidth', 2);
hold on;
plot(phase_shift_deg, cos(phase_shift_rad), 'r--', 'LineWidth', 1.5);
plot([0 360], [0 0], 'k:', 'LineWidth', 1);
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('Re[R(0)]');
title('Реальная часть корреляции');
legend('Эксперимент', 'Теория: cos(φ)', 'Location', 'south');
grid on;
xlim([0 360]);
set(gca, 'XTick', 0:45:360);

subplot(3,3,6);
plot(phase_shift_deg, peak_correlation_imag, 'b-', 'LineWidth', 2);
hold on;
plot(phase_shift_deg, sin(phase_shift_rad), 'r--', 'LineWidth', 1.5);
plot([0 360], [0 0], 'k:', 'LineWidth', 1);
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('Im[R(0)]');
title('Мнимая часть корреляции');
legend('Эксперимент', 'Теория: sin(φ)', 'Location', 'south');
grid on;
xlim([0 360]);
set(gca, 'XTick', 0:45:360);

subplot(3,3,7);
plot(phase_shift_deg, peak_correlation_abs_std, 'r-', 'LineWidth', 2);
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('σ[|R(0)|]');
title('Вариация пика корреляции');
grid on;
xlim([0 360]);

subplot(3,3,8);
plot(phase_shift_deg, unwrap(peak_correlation_angle)*180/pi, 'b-', 'LineWidth', 2);
hold on;
plot(phase_shift_deg, phase_shift_deg, 'r--', 'LineWidth', 1.5);
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('arg[R(0)] (градусы)');
title('Фаза корреляционного пика');
legend('Измеренная фаза', 'Входная фаза', 'Location', 'northwest');
grid on;
xlim([0 360]);

% График 9: Отклонение от теории
subplot(3,3,9);
error_theory = peak_correlation_abs - abs(peak_theory');
plot(phase_shift_deg, error_theory, 'k-', 'LineWidth', 1.5);
hold on;
plot([0 360], [0 0], 'r--', 'LineWidth', 1);
fill([phase_shift_deg, fliplr(phase_shift_deg)], ...
     [error_theory + peak_correlation_abs_std; ...
      flipud(error_theory - peak_correlation_abs_std)], ...
     'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
hold off;
xlabel('Фазовый сдвиг φ (градусы)');
ylabel('Отклонение от теории');
title('Ошибка аппроксимации');
grid on;
xlim([0 360]);

sgtitle('Влияние фазового сдвига на корреляцию PSS (u=34)', ...
        'FontSize', 16, 'FontWeight', 'bold');

figure('Name', 'Полярное представление', 'Position', [200, 200, 1200, 500]);

% Полярный график 1: Амплитуда корреляции
subplot(1,2,1, polaraxes);
polarplot(phase_shift_rad, peak_correlation_abs, 'b-', 'LineWidth', 2.5);
hold on;
polarplot(phase_shift_rad, abs(cos(phase_shift_rad)), 'r--', 'LineWidth', 1.5);
hold off;
title('Модуль корреляции |R(0)|', 'FontSize', 12);
legend('Эксперимент', 'Теория: |cos(φ)|', 'Location', 'best');
rlim([0 1.2]);

% Полярный график 2: Комплексная корреляция
subplot(1,2,2, polaraxes);
% Преобразуем в полярные координаты
[theta_corr, rho_corr] = cart2pol(peak_correlation_real, peak_correlation_imag);
polarplot(theta_corr, rho_corr, 'bo-', 'LineWidth', 2, 'MarkerSize', 3);
hold on;
polarplot(linspace(0, 2*pi, 100), ones(1,100), 'r--', 'LineWidth', 1.5);
hold off;
title('Комплексная корреляция R(0)', 'FontSize', 12);
legend('Траектория R(0)', 'Единичная окружность', 'Location', 'best');
rlim([0 1.2]);

figure('Name', 'Корреляционные функции при различных фазах', ...
       'Position', [250, 250, 1400, 800]);

% Выбираем характерные фазы
phase_examples = [0, 45, 90, 135, 180, 270];
n_examples = length(phase_examples);

for ex_idx = 1:n_examples
    phi_ex = phase_examples(ex_idx) * pi/180;

    phase_rotated_ex = pss_sequence * exp(1j * phi_ex);

    noise_ex = sigma_noise/sqrt(2) * (randn(N_pss, 1) + 1j*randn(N_pss, 1));
    received_ex = phase_rotated_ex + noise_ex;

    [R_ex, lags_ex] = xcorr(received_ex, pss_sequence, 'coeff');

    subplot(2, 3, ex_idx);
    plot(lags_ex, abs(R_ex), 'b-', 'LineWidth', 1.5);
    hold on;
    plot(lags_ex, real(R_ex), 'r-', 'LineWidth', 1);
    plot(lags_ex, imag(R_ex), 'g-', 'LineWidth', 1);

    zero_idx = find(lags_ex == 0);
    peak_val = R_ex(zero_idx);
    scatter(0, abs(peak_val), 100, 'k', 'filled');

    hold off;
    xlabel('τ (отсчеты)');
    ylabel('R(τ)');
    title(sprintf('φ = %d° : |R(0)| = %.3f', phase_examples(ex_idx), abs(peak_val)));
    legend('|R(τ)|', 'Re[R(τ)]', 'Im[R(τ)]', 'Пик', 'Location', 'best');
    grid on;
    xlim([-N_pss N_pss]);
end

sgtitle('Корреляционные функции при различных фазовых сдвигах', ...
        'FontSize', 14, 'FontWeight', 'bold');