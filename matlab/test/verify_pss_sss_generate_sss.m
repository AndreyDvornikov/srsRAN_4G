clear all; clc;

CONSTANT_SSS_LENGTH = 62;

[sss0_test, sss5_test] = pss_sss.generate_sss(0, 0);

% проверка на совпадение размера
assert( ...
    length(sss0_test) == CONSTANT_SSS_LENGTH && ...
    length(sss5_test) == CONSTANT_SSS_LENGTH ...
);

fprintf("Valid length (lteSSS and pss_sss.generate_sss) %d == %d\n", ...
    CONSTANT_SSS_LENGTH, CONSTANT_SSS_LENGTH ...
);

total_passed = 0;
total_tests = 0;

for NID1 = 0:167
    for NID2 = 0:2

        NCellID = 3 * NID1 + NID2;

        % Генерация с помощью lteSSS
        enb_sub0 = struct('NCellID', NCellID, 'NSubframe', 0);
        sss_lte_sub0 = lteSSS(enb_sub0);

        enb_sub5 = struct('NCellID', NCellID, 'NSubframe', 5);
        sss_lte_sub5 = lteSSS(enb_sub5);

        % Генерация с помощью нашей реализации
        [sss_my_sub0, sss_my_sub5] = pss_sss.generate_sss(NID1, NID2);

        matched_sub0 = 0;

        for n = 1:length(sss_lte_sub0)
            lte_val = sss_lte_sub0(n);
            my_val = sss_my_sub0(n);

            re_abs = abs(real(lte_val) - real(my_val));
            im_abs = abs(imag(lte_val) - imag(my_val));

            total_tests = total_tests + 1;

            if re_abs > 1e-10 || im_abs > 1e-10
                fprintf('NOK [NID1=%d NID2=%d sub0 idx=%d] re_abs=%.20e, im_abs=%.20e \n', ...
                    NID1, NID2, n, re_abs, im_abs);
            else
                fprintf('OK re_abs=%.20e, im_abs=%.20e \n', re_abs, im_abs);
                matched_sub0 = matched_sub0 + 1;
            end
        end

        assert(matched_sub0 == CONSTANT_SSS_LENGTH);
        fprintf("matched_sub0 OK (NID1=%d, NID2=%d)\n\n", NID1, NID2);
        total_passed = total_passed + matched_sub0;
        
        matched_sub5 = 0;

        for n = 1:length(sss_lte_sub5)
            lte_val = sss_lte_sub5(n);
            my_val = sss_my_sub5(n);

            re_abs = abs(real(lte_val) - real(my_val));
            im_abs = abs(imag(lte_val) - imag(my_val));

            total_tests = total_tests + 1;

            if re_abs > 1e-10 || im_abs > 1e-10
                fprintf('NOK [NID1=%d NID2=%d sub5 idx=%d] re_abs=%.20e, im_abs=%.20e \n', ...
                    NID1, NID2, n, re_abs, im_abs);
            else
                fprintf('OK re_abs=%.20e, im_abs=%.20e \n', re_abs, im_abs);
                matched_sub5 = matched_sub5 + 1;
            end
        end

        % Финальная проверка subframe 5
        assert(matched_sub5 == CONSTANT_SSS_LENGTH);
        fprintf("matched_sub5 OK (NID1=%d, NID2=%d)\n\n", NID1, NID2);
        total_passed = total_passed + matched_sub5;

    end
end

fprintf("Пройдено тестов: %d\n", total_passed);
fprintf("Всего тестов: %d\n", total_tests);
fprintf("\n");

if total_passed == total_tests
    fprintf("verify_generate_sss: OK\n");
else
    fprintf("verify_generate_sss: NOK\n");
end

% Финальное утверждение
assert(total_passed == total_tests);