function db_val = to_db(A) 
    % Возвращает магнитуду числа A в dB
    db_val = 20*log10(abs(A));
end 