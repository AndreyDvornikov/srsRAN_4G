function [complex_vec] = grc_file_read(path, samplerate)
%GRC_FILE_READ Summary of this function goes here
%   Detailed explanation goes here
arguments (Input)
    path
    samplerate
end

arguments (Output)
    complex_vec
end

fid = fopen(path, 'rb');
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

complex_vec = complex(data(1,:), data(2,:)).';
fprintf('Загружено: %d комплексных семплов\n', length(complex_vec));

end