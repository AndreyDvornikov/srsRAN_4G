% сюда будем добавлять новые записи!
% do not edit (for professional)
registered_fpaths = dictionary( ...
    "s1_6prb", pwd + "\large\converted\srsENB_signal_time_domain_6_prb.dat.mat", ...
    "s1_15prb", pwd + "\large\converted\srsENB_signal_time_domain_15_prb.dat.mat" ...
); 

prb_lte_params = struct(); 

prb_lte_params.prb_6 = struct(); 
prb_lte_params.prb_15 = struct(); 

if evalin("base", "SET_FORCE_SAMPLERATE") > 0
    prb_lte_params.prb_6.sample_rate = SET_FORCE_SAMPLERATE;
else 
    prb_lte_params.prb_6.sample_rate = 1.92e6;
end 

if evalin("base", "SET_FORCE_FFT_SIZE") > 0 
    prb_lte_params.prb_6.fft_size = SET_FORCE_FFT_SIZE;
else 
    prb_lte_params.prb_6.fft_size = 128;
end 


fprintf("s1 summary:\n");
s1(registered_fpaths, prb_lte_params); 

function s1(s1_arg_dict_registered_fpaths, s1_arg_phy_parameters ...
    ) 
    USE_SIGNAL_ID = evalin("base", "USE_SIGNAL_ID");
    
    if isKey(s1_arg_dict_registered_fpaths, USE_SIGNAL_ID)
        USE_SIGNAL_FILEPATH = s1_arg_dict_registered_fpaths(USE_SIGNAL_ID);
    else 
        error("Unknown USE_SIGNAL_ID (not exist in %s)", "registered_fpaths");
    end 

    if strcmp(extract(USE_SIGNAL_ID, "6prb"), "6prb")
        phy_parameters_current = s1_arg_phy_parameters.prb_6;
    end 
    
    if strcmp(extract(USE_SIGNAL_ID, "15prb"), "15prb") 
        phy_parameters_current = s1_arg_phy_parameters.prb_15;
    end 
    
    assignin("base", "prb_lte_params_selected", phy_parameters_current);
        
    m = matfile(USE_SIGNAL_FILEPATH, "Writable", false); 

    used_signal_length_ms = evalin("base", "SET_SIGNAL_LENGTH_MS");
    
    used_signal_samples = round( ...
        used_signal_length_ms * 1e-3 * phy_parameters_current.sample_rate ...
        );
    
    if used_signal_length_ms > 0 
        srs_signal_complex = m.srs_signal_complex(1:used_signal_samples, 1);
    else 
        srs_signal_complex = m.srs_signal_complex(1:end, 1);
    end 

    assignin("base", "lte_current_signal", srs_signal_complex);

    fprintf("\tUSE_SIGNAL_ID: %s\n", USE_SIGNAL_ID);
    fprintf("\tUSE_SIGNAL_FILEPATH: %s\n", USE_SIGNAL_FILEPATH);
    fprintf("\tUSE_SIGNAL_LENGTH_MS: %d\n", used_signal_length_ms);
    fprintf("\t--\n");
    fprintf("\tCOUNT_SAMPLES: %d\n", used_signal_samples);
    fprintf("\t--\n");
    fprintf("\tphy_parameters_current:\n");
    fields = fieldnames(phy_parameters_current);

    for i = 1:length(fields)
        field_name = fields{i};
        field_value = phy_parameters_current.(field_name);
        fprintf('\t\t%s = %s\n', field_name, mat2str(field_value));
    end

    precalc.pss() % lte_primary_syncronization_seq -> to workspace variables
    precalc.sss() % lte_secondary_syncronization_seq -> to workspace variables
end 