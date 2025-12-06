dir = fileparts(mfilename("fullpath"));

fpath = dir + "/../../+precalc";

lte_primary_syncronization_seq_roots    = [25,29,34];

lte_pss_roots_cnt                       = numel(...
    lte_primary_syncronization_seq_roots);

lte_primary_syncronization_seq      = cell(lte_pss_roots_cnt, 1);
lte_secondary_syncronization_seq    = cell(167 * ...
    numel(lte_primary_syncronization_seq_roots), lte_pss_roots_cnt);

for N_id_2 = 1:numel(lte_primary_syncronization_seq_roots)
    u = lte_primary_syncronization_seq_roots(N_id_2);
    lte_primary_syncronization_seq{N_id_2} = single(pss_sss.generate_pss(u));

    for N_id_1 = 0:167
        lte_secondary_syncronization_seq{N_id_2}{N_id_1 + 1} = ...
            single(pss_sss.generate_sss(N_id_1, N_id_2));
    end 
end 

save(fpath + "/lte_primary_syncronization_seq.mat", 'lte_primary_syncronization_seq', '-v7.3');
save(fpath + "/lte_secondary_syncronization_seq.mat", 'lte_secondary_syncronization_seq', '-v7.3');

fprintf("lte_primary_syncronization_seq saved to: %s\n", ...
    fpath);
fprintf("lte_secondary_syncronization_seq saved to: %s\n", ...
    fpath);