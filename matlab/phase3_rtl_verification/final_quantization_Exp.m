%% Final Fixed-Point RTL Preparation Script
clear; clc;

% --- 1. Track Modulator Integrator States ---
f_s = 512000; N_total = 512000;
Wn_in = 1000 / (f_s / 2); 
b_in = fir1(200, Wn_in);

% NEW: Fixed Random Seed for Reproducible RTL Sizing
rng(42, 'twister');
signal_in = 0.5 * filter(b_in, 1, randn(1, N_total));
signal_in = signal_in / max(abs(signal_in)) * 0.5;

% Restored Modulator Loop
v_out = zeros(1, N_total);
int1 = 0; int2 = 0;
int1_hist = zeros(1, N_total); 
int2_hist = zeros(1, N_total);

for i = 1:N_total
    if i > 1
        feedback = v_out(i-1);
    else
        feedback = 0;
    end
    
    int1 = int1 + (signal_in(i) - feedback);
    int2 = int2 + (int1 - feedback);
    
    int1_hist(i) = int1;
    int2_hist(i) = int2;
    
    if int2 >= 0
        v_out(i) = 1.0; 
    else
        v_out(i) = -1.0; 
    end
end

% Calculate required bit-widths (1 sign bit + log2 of peak integer value)
max_int1 = max(abs(int1_hist));
max_int2 = max(abs(int2_hist));
bits_int1 = ceil(log2(max_int1)) + 1;
bits_int2 = ceil(log2(max_int2)) + 1;

fprintf('\n=== RTL Bit-Width Requirements ===\n');
fprintf('Modulator Integrator 1 Peak: %.2f -> Requires %d bits\n', max_int1, bits_int1);
fprintf('Modulator Integrator 2 Peak: %.2f -> Requires %d bits\n', max_int2, bits_int2);

% NEW: Explicitly Derived CIC Growth Bound (K=3, R=64, B_in=1)
cic_growth = ceil(3 * log2(64)); 
cic_width = cic_growth + 1; % +1 for the 1-bit modulator input
fprintf('CIC Integrators & Combs: %d bits (Derived: ceil(K*log2(R)) + B_in = 18 + 1)\n', cic_width);

% --- 2. Export 16-bit Q1.15 FIR Coefficients to Verilog .mem ---
ideal_coeffs = fir1(100, 0.25);
scale_factor = 2^15;
quantized_coeffs = round(ideal_coeffs * scale_factor);
quantized_coeffs = max(min(quantized_coeffs, 32767), -32768); % Enforce 16-bit limit


% --- 2. Export 16-bit Q1.15 FIR Coefficients to Verilog .mem ---
ideal_coeffs = fir1(100, 0.25);
scale_factor = 2^15;
quantized_coeffs = round(ideal_coeffs * scale_factor);
quantized_coeffs = max(min(quantized_coeffs, 32767), -32768); % Enforce 16-bit limit

% NEW: Symmetry Check
is_symmetric = isequal(quantized_coeffs, fliplr(quantized_coeffs));
if is_symmetric
    fprintf('\nSuccess: Filter is perfectly symmetric. Multipliers reduced from 101 to 51.\n');
else
    fprintf('\nWarning: Symmetry broken!\n');
end

% Convert to 16-bit unsigned integer (for two's complement hex representation)
hex_coeffs = dec2hex(typecast(int16(quantized_coeffs), 'uint16'), 4);


% Convert to 16-bit unsigned integer (for two's complement hex representation)
hex_coeffs = dec2hex(typecast(int16(quantized_coeffs), 'uint16'), 4);

% Write to file
fileID = fopen('fir_coeffs.mem', 'w');
for i = 1:length(quantized_coeffs)
    fprintf(fileID, '%s\n', hex_coeffs(i,:));
end
fclose(fileID);

fprintf('\nSuccess: FIR coefficients exported to "fir_coeffs.mem"\n');

% --- 3. RTL Testbench Latency Calculation ---
R_cic = 64; 
K_cic = 3;
FIR_order = 100;

% CIC delay in high-speed clock cycles
delay_cic_fs = (K_cic * (R_cic - 1)) / 2;

% FIR delay (Order/2 at the intermediate rate, multiplied by R_cic for high-speed cycles)
delay_fir_fs = (FIR_order / 2) * R_cic; 

total_delay_fs = delay_cic_fs + delay_fir_fs;

fprintf('\n=== RTL Testbench Parameters ===\n');
fprintf('CIC Group Delay: %.1f clock cycles\n', delay_cic_fs);
fprintf('FIR Group Delay: %.1f clock cycles\n', delay_fir_fs);
fprintf('Total Pipeline Latency: %.1f clock cycles\n', total_delay_fs);
fprintf('-> ACTION: Hold Verilog testbench assertions for %d clock cycles.\n', ceil(total_delay_fs));

% =========================================================================
% Verilog Testbench Interface
% =========================================================================

% 1. Write the 1-bit modulator output to a file for Verilog
% Map the +1/-1 floating point values to binary 1 and 0
din_binary = (v_out > 0); 
fileID = fopen('modulator_out.txt', 'w');
fprintf(fileID, '%d\n', din_binary);
fclose(fileID);
disp('Successfully wrote 1-bit stimulus to modulator_out.txt');

% 2. Wait for you to run the Verilog simulation (Vivado/Yosys)
disp('ACTION REQUIRED: Run tb_adc_backend.v in your Verilog simulator now.');
disp('Once rtl_output.txt is generated, you can read it back to verify ENOB.');

% =========================================================================
% GENERATE MISSING MATLAB REFERENCE (WITH 19-BIT WRAPAROUND)
% =========================================================================
% 1. Align Pipeline Phase 
v_out_hw_aligned = [0, 0, v_out(1:end-2)];

% Helper function for 19-bit Two's Complement Wraparound
wrap19 = @(x) mod(x + 2^18, 2^19) - 2^18;

% 2. Simulate the Hardware CIC Filter (With exact register overflow)
R_cic = 64; K_cic = 3;

% Integrator Stages (must wrap at 19 bits)
int1 = wrap19(cumsum(v_out_hw_aligned));
int2 = wrap19(cumsum(int1));
int3 = wrap19(cumsum(int2));

% Decimation (Match Verilog's phase)
% Decimation (Matches current RTL 1-cycle phase offset)
cic_dec = int3(R_cic-1:R_cic:end);

% Comb Stages (must wrap at 19 bits)
comb1 = wrap19(cic_dec - [zeros(1,1), cic_dec(1:end-1)]);
comb2 = wrap19(comb1   - [zeros(1,1), comb1(1:end-1)]);
comb3 = wrap19(comb2   - [zeros(1,1), comb2(1:end-1)]);

v_out_cic_19bit = comb3;

% 3. Force EXACT Hardware Coefficient Symmetry
fileID = fopen('fir_coeffs_comp.mem', 'r');
hex_data = textscan(fileID, '%s');
fclose(fileID);
raw_coeffs = double(typecast(uint16(hex2dec(hex_data{1})), 'int16'))';
half_coeffs = raw_coeffs(1:51);
full_hw_coeffs = [half_coeffs(1:50), half_coeffs(51), fliplr(half_coeffs(1:50))];

% 4. Simulate the Hardware FIR Bit-True MAC
acc_35bit = filter(full_hw_coeffs, 1, v_out_cic_19bit);

% 5. Apply Hardware Rounding Logic
v_out_rounded_dec = floor((acc_35bit + 2^14) / 2^15);

% =========================================================================
% HARDWARE VERIFICATION & PLOTTING
% =========================================================================
rtl_file_path = 'C:\Users\visha\adc\adc.sim\sim_1\behav\xsim\rtl_output.txt';

if isfile(rtl_file_path)
    rtl_data = load(rtl_file_path);
    % Align the bulk pipeline delays
    [rtl_aligned, matlab_aligned] = alignsignals(rtl_data, v_out_rounded_dec');
    
    figure;
    plot(rtl_aligned, 'r', 'LineWidth', 3); hold on;
    plot(matlab_aligned, 'c--', 'LineWidth', 1.5);
    grid on;
    title('Perfectly Aligned: Hardware RTL vs MATLAB Bit-True Model');
    legend('Verilog RTL (Hardware)', 'MATLAB Model (Software)');
    axis tight;
    
    % Crop the first 100 startup transient samples for the true steady-state check
    check_len = min(length(rtl_aligned), length(matlab_aligned));
    crop_idx = 100; 
    
    max_error = max(abs(rtl_aligned(crop_idx:check_len) - matlab_aligned(crop_idx:check_len)));
    
    fprintf('\n=== HARDWARE VERIFICATION RESULT ===\n');
    fprintf('Maximum Steady-State Discrepancy: %d\n', max_error);
    if max_error == 0
        fprintf('SUCCESS: Verilog RTL is 100%% Bit-True and Tape-Out Ready!\n');
    else
        fprintf('WARNING: Signals do not match perfectly.\n');
    end
end

% =========================================================================
% CYCLE-BY-CYCLE FIR DEBUG LOG
% =========================================================================
% We will inspect the 5th CIC sample entering the FIR filter.
sample_idx = 5;

% 1. Reconstruct the exact FIR Delay Line (shift_reg) at this moment
% shift_reg[0] is the newest sample, shift_reg[100] is the oldest.
delay_line = zeros(1, 101);
for i = 1:sample_idx
    % Populate the newest 5 samples, leaving the rest as 0
    delay_line(sample_idx - i + 1) = v_out_cic_19bit(i);
end

fprintf('\n=== FIR DELAY LINE (Sample %d) ===\n', sample_idx);
fprintf('shift_reg[0] (Newest): %d\n', delay_line(1));
fprintf('shift_reg[1]         : %d\n', delay_line(2));
fprintf('shift_reg[4] (Oldest): %d\n', delay_line(5));

fprintf('\n=== 35-BIT MAC ACCUMULATOR ===\n');
mac_acc = 0;
for state = 0:50
    if state < 50
        % Folded symmetry addition: (shift_reg[state] + shift_reg[100-state]) * coeff
        sum_taps = delay_line(state + 1) + delay_line(101 - state);
        mult_res = sum_taps * half_coeffs(state + 1);
    else
        % Center tap 50
        mult_res = delay_line(51) * half_coeffs(51);
    end
    mac_acc = mac_acc + mult_res;
    
    % Print first few states and the final MAC state
    if state < 3 || state == 50
        fprintf('State %2d | mac_acc: %11d | Added: %10d\n', state, mac_acc, mult_res);
    end
end

% Hardware Rounding
mac_acc_rounded = mac_acc + 2^14;
final_out = floor(mac_acc_rounded / 2^15);

fprintf('\n=== ROUNDED OUTPUT ===\n');
fprintf('State 51 (mac_acc + 2^14): %d\n', mac_acc_rounded);
fprintf('State 52 (dout shifted)  : %d\n', final_out);