Fs = 1.92e6;           % частота дискретизации, Гц
N  = 100;              % максимальная "частота" (в Гц)

figure('Name','Complex exponentials via DeltaTheta'); hold on;
grid on;

for f = 1:N
    % период в сэмплах для частоты f
    Nf = round(Fs / f);      % количество отсчётов в одном периоде
    n  = 0:Nf-1;             % дискретный индекс (для оси X)

    % приращение фазы на один отсчёт
    DeltaTheta = 2*pi*f/Fs;  % Δθ = 2π f / Fs

    % явная форма (через exp): x[n] = e^{-j 2π f n / Fs}
    x_exp = exp(-1j * DeltaTheta * n);

    % рекуррентная форма через накопление фазы
    theta = zeros(1, Nf);
    x_rec = zeros(1, Nf);

    theta(1) = 0;            % φ[0] = 0
    x_rec(1) = exp(-1j*theta(1));

    for k = 2:Nf
        theta(k) = theta(k-1) + DeltaTheta;   % φ[k] = φ[k-1] + Δθ
        x_rec(k) = exp(-1j*theta(k));         % e^{-j φ[k]}
    end

    % для визуализации достаточно одной из форм, они совпадают
    plot(n, real(x_rec));
    plot(n, imag(x_rec), '--');
end

xlabel('n (дискретное время)');
ylabel('Re/Im\{e^{-j2\pi f n/F_s}\}');
title(sprintf('Один период комплексной экспоненты для f = 1..%d Гц, Fs=%.2e Гц', N, Fs));
