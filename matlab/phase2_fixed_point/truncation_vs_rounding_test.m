% =========================================================================
% Item 3 & 4: Hardware Rounding vs. Truncation Analysis (Bit-True Model)
% =========================================================================
clear; clc; close all;

% --- 1. Target Setup (OSR=256) ---
f_out_target = 2000; OSR = 256; f_s = f_out_target * OSR;
N_fft = 1024; N_transient = 128; N_total = (N_fft + N_transient) * OSR;
t = (0:N_total-1) / f_s;

f_res = f_out_target / N_fft;
f1 = 11 * f_res; f2 = 43 * f_res; f3 = 211 * f_res;
amp = 0.5 / 3;
signal_in = amp*sin(2*pi*f1*t) + amp*sin(2*pi*f2*t) + amp*sin(2*pi*f3*t);

% --- 2. 2nd-Order Modulator ---
v_out = zeros(1, N_total);
int1 = 0; int2 = 0;
for i = 1:N_total
    if i > 1
        feedback = v_out(i-1); 
    else
        feedback = 0; 
    end
    int1 = int1 + (signal_in(i) - feedback);
    int2 = int2 + (int1 - feedback);
    if int2 >= 0
        v_out(i) = 1.0; 
    else
        v_out(i) = -1.0; 
    end
end

% --- 3. CIC Decimation (Pure Integer Path) ---
R_fir = 4; R_cic = OSR / R_fir; K = 3;
cic_impulse = ones(1, R_cic);
filtered_sig = v_out;
for k = 1:K
    filtered_sig = filter(cic_impulse, 1, filtered_sig);
end
% KEEP AS INTEGER! We do NOT divide by R_cic^K here.
% This perfectly models the 19-bit hardware output of the CIC filter.
v_out_cic_19bit = filtered_sig(1:R_cic:end);

% --- 4. FIR Coefficients (16-bit Integer Q1.15) ---
ideal_coeffs = fir1(100, 0.25);
coeffs_16bit = round(ideal_coeffs * 2^15);
coeffs_16bit = max(min(coeffs_16bit, 32767), -32768); 

% --- 5. Run Hardware MAC Functions ---
disp('Simulating Bit-True FIR MAC with Round-to-Nearest...');
v_out_rounded = hardware_fir_mac(v_out_cic_19bit, coeffs_16bit, true);

disp('Simulating Bit-True FIR MAC with Blind Truncation...');
v_out_truncated = hardware_fir_mac(v_out_cic_19bit, coeffs_16bit, false);

% Decimate to final output rate
v_out_rounded_dec = v_out_rounded(1:R_fir:end);
v_out_truncated_dec = v_out_truncated(1:R_fir:end);

% --- 6. ENOB Calculation ---
% Convert the 20-bit hardware integers back to a standard +/- 1.0 float 
% scale so the ENOB calculation can measure the signal correctly.
hardware_gain = (R_cic^K); % The total mathematical gain introduced
enob_rounded = calc_enob(v_out_rounded_dec / hardware_gain, N_fft);
enob_truncated = calc_enob(v_out_truncated_dec / hardware_gain, N_fft);

fprintf('\n--- Truncation vs. Rounding Results (OSR=256) ---\n');
fprintf('Rounded Output (Add + Shift) : %.4f bits ENOB\n', enob_rounded);
fprintf('Truncated Output (Shift Only): %.4f bits ENOB\n', enob_truncated);
fprintf('Degradation Penalty          : %.4f bits\n', enob_rounded - enob_truncated);


% =========================================================================
% Local Function: Bit-True FIR MAC
% =========================================================================
function v_out_20bit = hardware_fir_mac(v_in_19bit, coeffs_16bit, use_rounding)
    N = length(v_in_19bit);
    num_taps = length(coeffs_16bit);
    v_out_20bit = zeros(1, N);
    
    % Shift Register
    delay_line = zeros(1, num_taps);
    rounding_constant = 2^14; % Hardware rounding (+0.5 in Q1.15)

    for i = 1:N
        % Shift new data in
        delay_line = [v_in_19bit(i), delay_line(1:end-1)];
        
        % 35-bit accumulation
        acc_35bit = sum(delay_line .* coeffs_16bit);

        if use_rounding
            acc_processed = acc_35bit + rounding_constant;
        else
            acc_processed = acc_35bit; % Blind truncation
        end

        % Arithmetic Right Shift by 15 (Discard fractional bits)
        % Cast to int64 to ensure MATLAB bitshift handles the signed integer properly
        v_out_20bit(i) = double(bitshift(int64(acc_processed), -15));
    end
end

% =========================================================================
% Local Function: ENOB Calculator
% =========================================================================
function enob = calc_enob(v_out_decimated, N_fft)
    v_out_steady = v_out_decimated(end - N_fft + 1 : end);
    v_out_steady = v_out_steady - mean(v_out_steady); % Remove DC
    window_dec = blackmanharris(N_fft)';
    power_spec = abs(fft(v_out_steady .* window_dec)).^2;
    power_spec = power_spec(1:N_fft/2);
    
    total_power = sum(power_spec(3:end)); 
    b1=12; b2=44; b3=212; win=4; % 1-indexed bins
    sig_power = sum(power_spec(b1-win:b1+win)) + sum(power_spec(b2-win:b2+win)) + sum(power_spec(b3-win:b3+win));
    
    sqnr = 10 * log10(sig_power / (total_power - sig_power));
    enob = (sqnr - 1.76) / 6.02;
end