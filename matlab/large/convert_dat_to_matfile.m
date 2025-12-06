% скрипт для конвертирования в более удобный для матлаба формат

convert("srsENB_signal_time_domain_6_prb.dat");
convert("srsENB_signal_time_domain_15_prb.dat");

function convert(filename)    
    dir = fileparts(mfilename("fullpath"));
    
    mat_folder = dir + "\converted";
    
    if ~exist(mat_folder, 'dir')
        mkdir(mat_folder);
    end
    
    to_convert_file = filename;
    to_convert_filepath = dir + "\" + to_convert_file;
    
    converted_file = to_convert_file + ".mat";
    converted_filepath = mat_folder + "\" + converted_file;

    fprintf("convert_dat_to_matfile:\n");
    fprintf("\tsrc: %s\n", to_convert_file);
    fprintf("\tsrc_path: %s\n", to_convert_filepath);
    fprintf("\tdst: %s\n", converted_file); 
    fprintf("\tdst_path: %s\n", converted_filepath);
    
    fid = fopen(to_convert_filepath, 'rb');
    data = fread(fid, [2, inf], 'float32=>single');
    fclose(fid);

    srs_signal_complex = complex(data(1,:), data(2,:)).';

    save(converted_filepath, 'srs_signal_complex', '-v7.3');
end 