inputCase1 = [1,2,3,4,5,6,7,8,9,10]; 
inputCase2 = [1,2,3,4,5,6,7,8,9,10,11]; 

sliceSizeCase1 = 2;
sliceSizeCase2 = 3;
sliceSizeCase3 = 4; 
sliceSizeCase4 = 12; 

%% test 1
test_passed = true; 

try
    [sliceCase1_1, tailCase1_1] = phy.fn.raw_buff_slicing(inputCase1, sliceSizeCase1);
    
    assert(isempty(tailCase1_1), "isempty(tailCase1_1) cond is not met");
    assert(width(sliceCase1_1) == 5, "width(sliceCase1_1) == 5 cond is not met");

    for i=1:width(sliceCase1_1) 
        assert(length(sliceCase1_1(:,i)) == sliceSizeCase1, "length(sliceCase1_1(i)) == sliceSizeCase1 cond is not met");
    end
catch ME
    warning(['Message: ' ME.message]);
    test_passed = false;
end 

try 
    [sliceCase1_2, tailCase1_2] = phy.fn.raw_buff_slicing(inputCase1, sliceSizeCase2);

    assert(isscalar(tailCase1_2), "isscalar(tailCase1_2) cond is not met");
    assert(tailCase1_2(1) == 10, "tailCase1_2(1) == 10 cond is not met"); 

    assert(width(sliceCase1_2) == 3, "width(sliceCase1_2) == 3 cond is not met");
    
    for i=1:width(sliceCase1_2) 
        assert(length(sliceCase1_2(:,i)) == sliceSizeCase2, "length(sliceCase1_2(i)) == sliceSizeCase2 cond is not met");
    end

catch ME
    warning(['Message: ' ME.message]);
    test_passed = false;
end 

try 
    [sliceCase1_3, tailCase1_3] = phy.fn.raw_buff_slicing(inputCase1, sliceSizeCase3);

    assert(length(tailCase1_3) == 2, "length(tailCase1_3) == 2 cond is not met");
    assert(tailCase1_3(1) == 9 && tailCase1_3(2) == 10, "tailCase1_3(1) == 9 && tailCase1_3(2) == 10 cond is not met");

    assert(width(sliceCase1_3) == 2, "width(sliceCase1_3) == 2 cond is not met");

    for i=1:width(sliceCase1_3) 
        assert(length(sliceCase1_3(:,i)) == sliceSizeCase3, "length(sliceCase1_3(i)) == sliceSizeCase3 cond is not met");
    end
catch ME
    warning(['Message: ' ME.message]);
    test_passed = false;
end 

try 
    [~, ~] = phy.fn.raw_buff_slicing(inputCase1, sliceSizeCase4);

    test_passed = false;
catch ME
    % должна выпасть ошибка
    fprintf("IT`S DEFINED ERROR!! Message: %s\n", ME.message);
end 

%% test 2
try
    [sliceCase2_1, tailCase2_1] = phy.fn.raw_buff_slicing(inputCase2, sliceSizeCase1);

    assert(isscalar(tailCase2_1), "isscalar(tailCase2_1) cond is not met");
    assert(tailCase2_1(1) == 11, "tailCase2_1(1) == 11 cond is not met"); 
    assert(width(sliceCase2_1) == 5, "width(sliceCase2_1) == 5 cond is not met");
    
    for i=1:width(sliceCase2_1) 
        assert(length(sliceCase2_1(:,i)) == sliceSizeCase1, "length(sliceCase2_1(i)) == sliceSizeCase1 cond is not met");
    end
catch ME 
    warning(['Message: ' ME.message]);
    test_passed = false;
end 

try 
    [sliceCase2_2, tailCase2_2] = phy.fn.raw_buff_slicing(inputCase2, sliceSizeCase2);

    assert(length(tailCase2_2) == 2, "length(tailCase2_2) == 2 cond is not met");
    assert(tailCase2_2(1) == 10 && tailCase2_2(2) == 11, "tailCase2_2(1) == 10 && tailCase2_2(2) == 11 cond is not met"); 
    assert(width(sliceCase2_2) == 3, "width(sliceCase2_2) == 3 cond is not met");
    
    for i=1:width(sliceCase2_2) 
        assert(length(sliceCase2_2(:,i)) == sliceSizeCase2, "length(sliceCase2_2(i)) == sliceSizeCase2 cond is not met");
    end
catch ME
    warning(['Message: ' ME.message]);
    test_passed = false;
end 

try 
    [sliceCase2_3, tailCase2_3] = phy.fn.raw_buff_slicing(inputCase2, sliceSizeCase3);
    
    assert(length(tailCase2_3) == 3, "length(tailCase2_2) == 3 cond is not met");
    assert(tailCase2_3(1) == 9 && tailCase2_3(2) == 10 && tailCase2_3(3) == 11, ... 
        "tailCase2_3(1) == 9 && tailCase2_3(2) == 10 && tailCase2_3(3) == 11 cond is not met");

    assert(width(sliceCase2_3) == 2, "width(sliceCase2_3) == 2 cond is not met");
    
    for i=1:width(sliceCase2_3) 
        assert(length(sliceCase2_3(:,i)) == sliceSizeCase3, "length(sliceCase2_3(:,i)) == sliceSizeCase3 cond is not met");
    end

catch ME

end 

try
    [~, ~] = phy.fn.raw_buff_slicing(inputCase2, sliceSizeCase4);
    test_passed = false;
catch ME
    % должна выпасть ошибка
    fprintf("IT`S DEFINED ERROR!! Message: %s\n", ME.message);
end 

assert(test_passed, "test_passed not passed");
fprintf("verify_phy_fn_raw_buff_slicing: OK\n");

clear inputCase1 inputCase2 sliceSizeCase1 sliceSizeCase2 sliceSizeCase3 sliceSizeCase4 ...
    sliceCase1_1 tailCase1_1 sliceCase1_2 tailCase1_2 ...
    sliceCase1_3 tailCase1_3 sliceCase2_1 tailCase2_1 ...
    sliceCase2_2 tailCase2_2 sliceCase2_3 tailCase2_3 ...
    sliceCase2_4 tailCase2_4 test_passed ME i;

% Логи: 
% verify_phy_fn_raw_buff_slicing
% IT`S DEFINED ERROR!! Message: raw_buff_slicing() invalid input data: no to slice
% IT`S DEFINED ERROR!! Message: raw_buff_slicing() invalid input data: no to slice
% verify_phy_fn_raw_buff_slicing: OK