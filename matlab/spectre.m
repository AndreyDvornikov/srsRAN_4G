function samples = load_gnuradio_complex(filename, samplerate)
    fid = fopen(filename, 'rb');
    if fid == -1
        error('Не удалось открыть файл: %s', filename);
    end
    
    fseek(fid, 0, 'eof');
    fileSize = ftell(fid);
    numSamples = fileSize / 8;
    fseek(fid, 0, 'bof');
    
    fprintf('Размер файла: %.2f МБ\n', fileSize/1024/1024);
    fprintf('Количество семплов: %d (%.3f сек)\n', numSamples, numSamples/samplerate);
    
    data = fread(fid, [2, numSamples], 'float32=>float32');
    fclose(fid);
    
    samples = complex(data(1,:), data(2,:)).';
    fprintf('Загружено: %d комплексных семплов\n', length(samples));
end

samples = load_gnuradio_complex("./large/srsENB_signal_time_domain_6_prb.dat");

%% 2D WATERFALL - ОПТИМИЗИРОВАНО ДЛЯ 15 PRB
Fs = 1.92e6;  % Sample rate для 15 PRB (3 MHz bandwidth)

% Параметры для 15 PRB (3 MHz LTE)
nfft = 256;            % FFT 256 для 15 PRB (180 активных поднесущих)
window = hamming(64);  % Окно ~33.3 мкс (половина OFDM символа)
overlap = 48;          % 75% перекрытие

% Вычисление спектрограммы
fprintf('\nВычисление спектрограммы...\n');
tic;
[S, F, T] = spectrogram(samples, window, overlap, nfft, Fs, 'centered');
elapsed = toc;
fprintf('Готово за %.2f сек\n', elapsed);

% Преобразование в дБ
S_dB = 10*log10(abs(S).^2 + eps);

%% ПОСТРОЕНИЕ 2D WATERFALL
figure('Position', [100 100 1600 800], 'Color', 'w');

imagesc(T*1000, F/1e6, S_dB);
axis xy;

% Подписи
xlabel('Время (мс)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Частота (МГц)', 'FontSize', 13, 'FontWeight', 'bold');
title('LTE 15 PRB (3 MHz) - 2D Waterfall', 'FontSize', 15, 'FontWeight', 'bold');

% Цветовая карта
colormap(jet);
c = colorbar;
c.Label.String = 'Мощность (дБ)';
c.Label.FontSize = 12;

% Динамический диапазон 70 дБ
caxis([max(S_dB(:))-70, max(S_dB(:))]);

% Сетка
grid on;
set(gca, 'GridAlpha', 0.3, 'LineWidth', 1);

% Информационная панель
dim = [0.15 0.75 0.25 0.15];
str = {
    sprintf('FFT: %d (оптимально для 15 PRB)', nfft),
    sprintf('Разрешение по частоте: %.2f кГц (1 поднесущая LTE)', Fs/nfft/1e3),
    sprintf('Разрешение по времени: %.2f мкс', (length(window)-overlap)/Fs*1e6),
    sprintf('Активных поднесущих: 180 (15 PRB × 12)'),
    sprintf('Полезная полоса: 2.7 МГц')
};
annotation('textbox', dim, 'String', str, 'FitBoxToText', 'on', ...
           'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10);

fprintf('\n=== ПАРАМЕТРЫ LTE 15 PRB ===\n');
fprintf('Sample Rate: %.2f МГц\n', Fs/1e6);
fprintf('FFT размер: %d\n', nfft);
fprintf('Активных поднесущих: 180 (15 PRB × 12)\n');
fprintf('Частотное разрешение: %.2f кГц (= 15 кГц LTE subcarrier)\n', Fs/nfft/1e3);
fprintf('Размер окна: %d семплов (%.2f мкс)\n', length(window), length(window)/Fs*1e6);
fprintf('Временное разрешение: %.2f мкс\n', (length(window)-overlap)/Fs*1e6);
fprintf('Overlap: %.1f%%\n', overlap/length(window)*100);
fprintf('Размер спектрограммы: %d частот × %d окон\n', size(S,1), size(S,2));
fprintf('Пиковая мощность: %.2f дБ\n', max(S_dB(:)));
