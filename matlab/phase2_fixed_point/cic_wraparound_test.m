% =========================================================================
% Item 6: CIC Two's Complement Wraparound Proof (Hogenauer's Theorem)
% =========================================================================
clear; clc;

% --- 1. Target Setup (1-bit chaotic input) ---
N = 8192; 
rng(42, 'twister');
v_in = sign(randn(1, N)); 
v_in(v_in == 0) = 1;

R = 64; K = 3;

% --- 2. Infinite Precision CIC (Standard Math) ---
int_ideal = v_in;
for k = 1:K
    int_ideal = cumsum(int_ideal);
end
dec_ideal = int_ideal(1:R:end);

comb_ideal = dec_ideal;
for k = 1:K
    temp = zeros(size(comb_ideal));
    temp(1) = comb_ideal(1);
    for i = 2:length(comb_ideal)
        temp(i) = comb_ideal(i) - comb_ideal(i-1);
    end
    comb_ideal = temp;
end

% --- 3. Hardware Bit-True CIC (19-bit Two's Complement Wrap) ---
% Inline function for 19-bit wrap: limits bounds to [-262144, 262143]
wrap19 = @(x) mod(x + 262144, 524288) - 262144;

int_wrap = v_in;
for k = 1:K
    temp = zeros(size(int_wrap));
    temp(1) = wrap19(int_wrap(1));
    for i = 2:length(int_wrap)
        temp(i) = wrap19(temp(i-1) + int_wrap(i)); % Force integer wrap
    end
    int_wrap = temp;
end
dec_wrap = int_wrap(1:R:end);

comb_wrap = dec_wrap;
for k = 1:K
    temp = zeros(size(comb_wrap));
    temp(1) = wrap19(comb_wrap(1));
    for i = 2:length(comb_wrap)
        temp(i) = wrap19(comb_wrap(i) - comb_wrap(i-1)); % Force integer wrap
    end
    comb_wrap = temp;
end

% --- 4. Compare Results ---
fprintf('\n=== Item 6: CIC Wraparound Proof ===\n');
fprintf('Max Infinite Precision Integrator Value: %.0f\n', max(abs(int_ideal)));
fprintf('Max 19-Bit Hardware Integrator Value   : %.0f\n', max(abs(int_wrap)));
fprintf('Maximum Final Output Error             : %.0f\n', max(abs(comb_ideal - comb_wrap)));