function [slices, tail] = raw_buff_slicing(inputBuffer, sliceSize)
%RAW_BUFF_SLICEING наризает буфер (inputBuffer) длинной N на m частей длинной k (sliceSize)
%если размер буфера не кратен m, то N - (N % m) элементов откидываются и
%помещаются в tail
%   Input:
%       inputBuffer - входной буфер (N элементов)
%       sliceSize   - размер каждого куска (k элементов)
%   Output: 
%       
arguments (Input)
    inputBuffer(:, 1) double {mustBeVector} 
    sliceSize double {mustBeInteger, mustBePositive}
end

arguments (Output)
    slices (:, :) double
    tail (:, 1) double
end

if isrow(inputBuffer)
    inputBuffer = inputBuffer(:);
end

N = length(inputBuffer);
K = floor(N / sliceSize);

tail_idx = K * sliceSize; 

to_slicing = inputBuffer(1:tail_idx); 
tail = inputBuffer(tail_idx + 1: end); 

assert(K > 0, "raw_buff_slicing() invalid input data: no to slice");

slices = reshape(to_slicing, sliceSize, K);
end