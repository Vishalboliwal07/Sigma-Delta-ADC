% =========================================================================
% Phase 2 Verification: Closed-Loop Quantized ENOB Test
% =========================================================================
clear; clc; close all;

%% 1. Setup & Modulator Simulation (Target OSR = 256)
f_out_target = 2000;
OSR = 256;
f_s = f_out_target * OSR;
N_fft = 1024;                
N_transient = 128;           
N_dec_total = N_fft + N_transient; 
N_total = N_dec_total * OSR; 
t = (0:N_total-1) / f_s;     

% Coherent Frequencies
f_res = f_out_target / N_fft;
f1 = 11 * f_res; f2 = 43 * f_res; f3 = 211 * f_res; 
amp = 0.5 / 3;      
signal_in = amp*sin(2*pi*f1*t) + amp*sin(2*pi*f2*t) + amp*sin(2*pi*f3*t);

% 2nd-Order Modulator
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

%% 2. Generate FIR Coefficients
ideal_coeffs = fir1(100, 0.25);

% Quantize to 16-bit (Q1.15 format)
fractional_bits = 15;
scale_factor = 2^fractional_bits;
quantized_coeffs = round(ideal_coeffs * scale_factor);
quantized_coeffs = max(min(quantized_coeffs, 32767), -32768);
simulated_fixed_coeffs = quantized_coeffs / scale_factor;

%% 3. Decimation (Coarse CIC)
R_fir = 4;
R_cic = OSR / R_fir;
K = 3;
cic_impulse = ones(1, R_cic);
filtered_sig = v_out;
for k = 1:K
    filtered_sig = filter(cic_impulse, 1, filtered_sig); 
end
v_out_cic = filtered_sig(1:R_cic:end) / (R_cic^K);

%% 4. Apply FIR & Calculate ENOB for BOTH Cases

% --- Case A: Ideal Floating-Point FIR ---
v_out_fir_ideal = filter(ideal_coeffs, 1, v_out_cic);
v_out_dec_ideal = v_out_fir_ideal(1:R_fir:end);
enob_ideal = calc_enob(v_out_dec_ideal, N_fft);

% --- Case B: 16-bit Q1.15 Quantized FIR ---
v_out_fir_quant = filter(simulated_fixed_coeffs, 1, v_out_cic);
v_out_dec_quant = v_out_fir_quant(1:R_fir:end);
enob_quant = calc_enob(v_out_dec_quant, N_fft);

%% 5. Print Results
fprintf('\n=== Phase 2 Quantization Verification (OSR = 256) ===\n');
fprintf('Ideal Floating-Point ENOB:   %.4f bits\n', enob_ideal);
fprintf('16-bit Q1.15 Quantized ENOB: %.4f bits\n', enob_quant);
fprintf('ENOB Degradation:            %.4f bits\n', enob_ideal - enob_quant);

% Helper Function for FFT & ENOB calculation
function enob = calc_enob(v_out_decimated, N_fft)
    v_out_steady = v_out_decimated(end - N_fft + 1 : end);
    v_out_steady = v_out_steady - mean(v_out_steady); 
    
    window_dec = blackmanharris(N_fft)';
    spectrum_dec = fft(v_out_steady .* window_dec);
    power_spectrum_dec = abs(spectrum_dec(1:N_fft/2)).^2;
    
    total_power = sum(power_spectrum_dec(3:end)); 
    b1 = 11+1; b2 = 43+1; b3 = 211+1; win_w = 4;
    sig_power = sum(power_spectrum_dec(b1-win_w:b1+win_w)) + ...
                sum(power_spectrum_dec(b2-win_w:b2+win_w)) + ...
                sum(power_spectrum_dec(b3-win_w:b3+win_w));
                
    noise_power = total_power - sig_power;
    sqnr_dec = 10 * log10(sig_power / noise_power);
    enob = (sqnr_dec - 1.76) / 6.02;
end