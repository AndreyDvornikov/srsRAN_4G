% Путь до файла из grc
filepath    = "./large/srsENB_signal_time_domain_6_prb.dat";
samplerate  = 1.92e6; 

complex_vec = utils.grc_file_read(filepath, samplerate);

% Параметры для анализа спектра
% samplerate - 1.92e6 это 6 PRB
% 1 PRB...

switch samplerate 
    case 1.92e6 % for 6 PRB BW 3
        disp('gg');

        N_FFT_SIZE      = 256;
        N_SC_OVERLAP    = 64; 
    case 3.84e6 % for 15 PRB BW 6
        disp('gg');

        N_FFT_SIZE      = 512; 
        N_SC_OVERLAP    =64;
    otherwise
        error("Unknown samplerate");
end 