function res = complex_corr_norm_sqabs(A, B) 
    % Возвращает модуль умножения комплексного числа 
    % на его комплексносопряжённое 

    % сумма модулей в квадратов
    % энергия комплексных чисел А
    Ea = sum(abs(A).^2) + eps;

    % энергия комплексных чисел B
    Eb = sum(abs(B).^2) + eps;

    % Коэффициент нормирования
    norm_coeff = Ea * Eb; 

    res = (abs(conj(A) * B) .^ 2) / (norm_coeff + eps);
end 