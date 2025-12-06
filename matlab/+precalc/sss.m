function sss() 
    dir = fileparts(mfilename("fullpath"));

    m = matfile(dir + "\lte_secondary_syncronization_seq.mat", "Writable", false);

    assignin("base", "lte_secondary_syncronization_seq", m.lte_secondary_syncronization_seq);
end 