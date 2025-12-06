function complex_pss = generate_pss(root_u)
%GENERATE_PSS Summary of this function goes here
%   https://sharetechnote.com/html/Handbook_LTE_PSS.html
%   PSS в частотной области (3GPP 36.211 6.11.1.1)

arguments (Input)
    root_u
end

arguments (Output)
    complex_pss
end

d_u = @(n,u) (n <= 30).*exp(-1j*pi*u.*n.*(n+1)/63) + ...
    (n >= 31).*exp(-1j*pi*u.*(n+1).*(n+2)/63);

complex_pss = d_u((0:61), root_u);

end