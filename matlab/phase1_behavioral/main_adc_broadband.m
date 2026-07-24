% =========================================================================
% Broadband Test: 2nd-Order Delta-Sigma ADC (Filtered Noise Input)
% =========================================================================
clear; clc; close all;

%% 1. Specifications & Broadband Signal Generation
f_out_target = 2000;         % Nyquist output rate (2 ksps)
OSR = 256;                   % Oversampling Ratio
f_s = f_out_target * OSR;    % Modulator clock (512 kHz)

N_fft = 1024;                
N_transient = 128;           
N_dec_total = N_fft + N_transient; 
N_total = N_dec_total * OSR; 

t = (0:N_total-1) / f_s;     

% --- NEW: Set fixed random seed for reproducible noise ---
rng(42, 'twister'); 

% Generate White Gaussian Noise
raw_noise = randn(1, N_total);

% Sharp Low-Pass Filter to limit noise to the 1 kHz baseband
Wn_in = 1000 / (f_s / 2); 
b_in = fir1(200, Wn_in); % 200th-order input filter for a sharp cutoff
signal_in = filter(b_in, 1, raw_noise);

% Scale to 0.5 peak amplitude to prevent quantizer overload
signal_in = 0.5 * (signal_in / max(abs(signal_in)));


%% 2. 2nd-Order Modulator
disp('Simulating 2nd-Order Modulator with Broadband Input...');
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

%% 3. Decimation (Applied to Modulator AND Ideal Input)
disp('Running Decimation Filters...');
R_cic = 64; K = 3; R_fir = 4;
cic_impulse = ones(1, R_cic);
fir_coeffs = fir1(100, 0.25); 

% --- Decimate Modulator Output ---
% CIC
filtered_out = filter(cic_impulse, 1, v_out); 
for k = 2:K, filtered_out = filter(cic_impulse, 1, filtered_out); end
v_out_cic = filtered_out(1:R_cic:end) / (R_cic^K);
% FIR
v_out_fir = filter(fir_coeffs, 1, v_out_cic);
v_out_decimated = v_out_fir(1:R_fir:end);

% --- Decimate Ideal Input (The Golden Reference) ---
% We do this to find the EXACT expected signal power, accounting for filter droop
filtered_in = filter(cic_impulse, 1, signal_in); 
for k = 2:K, filtered_in = filter(cic_impulse, 1, filtered_in); end
v_in_cic = filtered_in(1:R_cic:end) / (R_cic^K);
% FIR
v_in_fir = filter(fir_coeffs, 1, v_in_cic);
v_in_decimated = v_in_fir(1:R_fir:end);

disp('Decimation complete.');

%% 4. Steady-State Broadband Power Analysis (IEEE Curve-Fitting Method)
% Slice steady-state buffer
v_out_steady = v_out_decimated(end - N_fft + 1 : end);
v_out_steady = v_out_steady - mean(v_out_steady); 

v_in_steady = v_in_decimated(end - N_fft + 1 : end);
v_in_steady = v_in_steady - mean(v_in_steady); 

% Step 1: Align the signals in time using cross-correlation
[c, lags] = xcorr(v_out_steady, v_in_steady);
[~, max_idx] = max(abs(c));
delay = lags(max_idx);

if delay > 0
    v_out_aligned = v_out_steady(delay+1:end);
    v_in_aligned = v_in_steady(1:end-delay);
elseif delay < 0
    v_out_aligned = v_out_steady(1:end+delay);
    v_in_aligned = v_in_steady(-delay+1:end);
else
    v_out_aligned = v_out_steady;
    v_in_aligned = v_in_steady;
end

% Step 2: Least-Squares Gain Matching
% Find the exact mathematical gain the modulator applied to the signal
optimal_gain = sum(v_out_aligned .* v_in_aligned) / sum(v_in_aligned.^2);

% Step 3: Extract True Noise
% Scale the ideal signal to match the modulator's output perfectly, then subtract
v_in_fitted = optimal_gain * v_in_aligned;
residual_noise = v_out_aligned - v_in_fitted;

% Step 4: Calculate True Power (Variance = AC Power)
P_sig_true = var(v_in_fitted);
P_noise_true = var(residual_noise);

sqnr_dec = 10 * log10(P_sig_true / P_noise_true);
enob_dec = (sqnr_dec - 1.76) / 6.02;

fprintf('\n=== FINAL BROADBAND RESULTS (OSR = %d) ===\n', OSR);
fprintf('STF Modulator Gain: %.4f\n', optimal_gain);
fprintf('Filtered SQNR: %.2f dB\n', sqnr_dec);
fprintf('Filtered ENOB: %.2f bits\n', enob_dec);


%% 5. Plotting Broadband Spectrum
window_dec = blackmanharris(N_fft)';
spectrum_dec = fft(v_out_steady .* window_dec);
power_spectrum_dec = abs(spectrum_dec(1:N_fft/2)).^2;
mag_out_db_dec = 10*log10(power_spectrum_dec / max(power_spectrum_dec));
f_axis_dec = (0:N_fft/2-1) * (f_out_target/N_fft);

figure;
plot(f_axis_dec, mag_out_db_dec, 'b', 'LineWidth', 1);
grid on; hold on;
xline(1000, 'r--', 'LineWidth', 2, 'Label', '1 kHz Cutoff');
axis([0 (f_out_target/2) -180 0]);
title('Steady-State Broadband Output Spectrum');
xlabel('Frequency (Hz)');
ylabel('Normalized Magnitude (dB)');