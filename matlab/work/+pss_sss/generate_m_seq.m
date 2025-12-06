function seq = generate_m_seq(taps)
    % Генерирует m-последовательность длины 31
    % taps - массив полинома, где idx - элемент (x_idx), значение - степень

    x = zeros(1, 31);
    x(1:5) = [0 0 0 0 1];

    for i = 0:25
        feedback = 0;
        for tap = taps
            feedback = mod(feedback + x(i + tap + 1), 2);
        end
        x(i + 6) = feedback;
    end

    seq = x;
end
