% модель math_mca_macro
% MCA - FMA с обратной связью
% A * B + C 

% имитированные два массива 
% комплексных чисел
I_y = int16([1, 2, 3, 4, 3, 2, 1]); % Re
Q_y = int16([3, 2, 1, 5, 3, 1, 6]); % Im

assert(numel(I_y) == numel(Q_y), "I_y and Q_y sizes not equal");

% Комплексно сопряжённый фрагмент
% I_y и Q_y 
I_s = int16([4, 3, 2]);
Q_s = int16([-5, -3, -1]);

assert(numel(I_y) == numel(Q_y), "I_s and Q_s sizes not equal");

idx_s = 1;

% аккумулятор для реальной части
acc_re = int32(0);

% аккумулятор для мнимой части
acc_im = int32(0);

% y * conj(s) = (Iy+jQy)*(Is - jQs)

max_mag = 0;

for idx_iq = 1:numel(I_y)
    Iy = int32(I_y(idx_iq));
    Qy = int32(Q_y(idx_iq));
    Is = int32(I_s(idx_s));
    Qs = int32(Q_s(idx_s));

    % Re += Iy*Is - Qy*Qs
    acc_re = fma(Iy, Is, acc_re);
    acc_re = fma(-Qy, Qs, acc_re);

    % Im += Iy*Qs + Qy*Is
    acc_im = fma(Iy, Qs, acc_im);
    acc_im = fma(Qy, Is, acc_im);

    idx_s = idx_s + 1;
    
    if idx_s > numel(I_s)
        idx_s = 1;
        
        mag2 = acc_re*acc_re + acc_im*acc_im;
        
        if (mag2 > max_mag) 
            max_mag = mag2;
        end 

        fprintf("Mag IQ %d\n", mag2);
        
        acc_re = int32(0);
        acc_im = int32(0);
    end
end

% fma operation example
function f = fma(a,b,c)
    f = a * b + c;
end 

ref_y = complex(double(I_y), double(Q_y));
ref_s = complex(double(I_s), double(Q_s)); % уже комплексно сопряжённое

ref_y_seq_s = ref_y(4:6);

r = sum(ref_y_seq_s .* ref_s);
max_ref = real(r)^2 + imag(r)^2;

assert(max_ref == max_mag, "Tests failed");
fprintf("max_ref = max_mag = %d\n", max_mag);