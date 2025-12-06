function pss() 
    dir = fileparts(mfilename("fullpath"));

    m = matfile(dir + "\lte_primary_syncronization_seq.mat", "Writable", false);

    assignin("base", "lte_primary_syncronization_seq", m.lte_primary_syncronization_seq);
end 