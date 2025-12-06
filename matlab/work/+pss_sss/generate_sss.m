function [sss0, sss5] = generate_sss(NID1, NID2)
    % Генерирует Secondary Synchronization Signal (SSS)
    assert(NID1 <= 167, "NID1 must be <= 167") 
    assert(NID1 >= 0, "NID1 must be positive"); 

    % NID1 - Cell ID group (0-167)
    % NID2 - ID внутри группы (0-2)
    % sss0 - SSS для subframe 0 (массив-столбец 62x1, комплексный)
    % sss5 - SSS для subframe 5 (массив-столбец 62x1, комплексный)

    % Вычисление параметров согласно 3GPP TS 36.211
    q_prime = floor(NID1/30);
    q = floor((NID1 + q_prime*(q_prime+1)/2)/30);
    m_prime = NID1 + q*(q+1)/2;
    m0 = mod(m_prime, 31);
    m1 = mod(m0 + floor(m_prime/31) + 1, 31);

    % x_s: m-последовательность с полиномом x^5 + x^2 + 1
    x_s = pss_sss.generate_m_seq([0, 2]);

    % x_c: m-последовательность с полиномом x^5 + x^3 + 1  
    x_c = pss_sss.generate_m_seq([0, 3]);

    % x_z: m-последовательность с полиномом x^5 + x^4 + x^2 + x + 1
    x_z = zeros(1, 31);
    x_z(1:5) = [0 0 0 0 1];
    for i = 0:25
        x_z(i+6) = mod(x_z(i+5) + x_z(i+3) + x_z(i+2) + x_z(i+1), 2);
    end

    % Преобразование в биполярные последовательности
    s_tilda = 1 - 2*x_s;
    c_tilda = 1 - 2*x_c;
    z_tilda = 1 - 2*x_z;

    %%%%% Генерация четных элементов (even) %%%%%

    % s0_m0 для subframe 0
    s0_m0_even = zeros(1, 31);
    for n = 0:30
        s0_m0_even(n+1) = s_tilda(mod(n + m0, 31) + 1);
    end

    % s1_m1 для subframe 5
    s1_m1_even = zeros(1, 31);
    for n = 0:30
        s1_m1_even(n+1) = s_tilda(mod(n + m1, 31) + 1);
    end

    % c0 для четных элементов
    c0_even = zeros(1, 31);
    for n = 0:30
        c0_even(n+1) = c_tilda(mod(n + NID2, 31) + 1);
    end

    d_even_sub0 = s0_m0_even .* c0_even;
    d_even_sub5 = s1_m1_even .* c0_even;

    %%%%% Генерация нечетных элементов (odd) %%%%%

    % s1_m1 для subframe 0
    s1_m1_odd = zeros(1, 31);
    for n = 0:30
        s1_m1_odd(n+1) = s_tilda(mod(n + m1, 31) + 1);
    end

    % s0_m0 для subframe 5
    s0_m0_odd = zeros(1, 31);
    for n = 0:30
        s0_m0_odd(n+1) = s_tilda(mod(n + m0, 31) + 1);
    end

    % c1 для нечетных элементов
    c1_odd = zeros(1, 31);
    for n = 0:30
        c1_odd(n+1) = c_tilda(mod(n + NID2 + 3, 31) + 1);
    end

    % z1_m0 для subframe 0
    z1_m0_odd = zeros(1, 31);
    for n = 0:30
        z1_m0_odd(n+1) = z_tilda(mod(n + mod(m0, 8), 31) + 1);
    end

    % z1_m1 для subframe 5
    z1_m1_odd = zeros(1, 31);
    for n = 0:30
        z1_m1_odd(n+1) = z_tilda(mod(n + mod(m1, 8), 31) + 1);
    end

    d_odd_sub0 = s1_m1_odd .* c1_odd .* z1_m0_odd;
    d_odd_sub5 = s0_m0_odd .* c1_odd .* z1_m1_odd;

    %%%%% Формирование итоговых последовательностей %%%%%

    % SSS для subframe 0 (62x1 комплексный столбец)
    sss0_row = zeros(1, 62);
    sss0_row(1:2:end) = d_even_sub0;  % Четные позиции (1,3,5,...)
    sss0_row(2:2:end) = d_odd_sub0;   % Нечетные позиции (2,4,6,...)
    sss0 = complex(sss0_row)';  % Преобразуем в комплексный столбец (62x1)

    % SSS для subframe 5 (62x1 комплексный столбец)
    sss5_row = zeros(1, 62);
    sss5_row(1:2:end) = d_even_sub5;
    sss5_row(2:2:end) = d_odd_sub5;
    sss5 = complex(sss5_row)';  % Преобразуем в комплексный столбец (62x1)
end