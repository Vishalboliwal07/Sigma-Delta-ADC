% =========================================================================
% Final Master Script: 2nd-Order Delta-Sigma ADC & 2-Stage Decimation
% =========================================================================
clear; clc; close all;

%% 1. Specifications & Coherent Padding
f_out_target = 2000;         % Nyquist output rate (2 ksps)
OSR = 256;                   % Oversampling Ratio
f_s = f_out_target * OSR;    % Modulator clock (512 kHz)

N_fft = 1024;                % FFT window length (Decimated)
N_transient = 128;           % Buffer array to let filters settle
N_dec_total = N_fft + N_transient; 
N_total = N_dec_total * OSR; % Total modulator samples to simulate

t = (0:N_total-1) / f_s;     % Time vector

% Coherent frequencies based EXACTLY on the steady-state N_fft window
f_res = f_out_target / N_fft;
f1 = 11 * f_res; 
f2 = 43 * f_res; 
f3 = 211 * f_res; 

amp = 0.5 / 3;      
signal_in = amp*sin(2*pi*f1*t) + amp*sin(2*pi*f2*t) + amp*sin(2*pi*f3*t);

%% 2. 2nd-Order Modulator
disp('Simulating 2nd-Order Modulator...');
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

%% 3. Decimation (CIC Coarse + FIR Fine)
disp('Running 2-Stage Decimation (CIC R=64 + FIR R=4)...');

% Stage 1: CIC (R=64, SINC^3)
R_cic = 64; K = 3;
cic_impulse = ones(1, R_cic);
filtered_sig = v_out;
for k = 1:K
    filtered_sig = filter(cic_impulse, 1, filtered_sig); 
end
v_out_cic = filtered_sig(1:R_cic:end) / (R_cic^K);

% Stage 2: FIR (R=4)
R_fir = 4;
% 1 kHz target cutoff at 8 kHz intermediate sample rate (Wn = 0.25)
fir_coeffs = fir1(100, 0.25); 
v_out_fir = filter(fir_coeffs, 1, v_out_cic);
v_out_decimated = v_out_fir(1:R_fir:end);

disp('Decimation complete.');

%% 4. Steady-State FFT Analysis
% Slice off the transient buffer to capture pure steady-state data
v_out_steady = v_out_decimated(end - N_fft + 1 : end);
v_out_steady = v_out_steady - mean(v_out_steady); % Remove DC

window_dec = blackmanharris(N_fft)';
spectrum_dec = fft(v_out_steady .* window_dec);
power_spectrum_dec = abs(spectrum_dec(1:N_fft/2)).^2;

total_power = sum(power_spectrum_dec(3:end)); % Skip DC bins

% Coherent signal bins (1-indexed for MATLAB)
b1 = 11+1; b2 = 43+1; b3 = 211+1; win_w = 4;
sig_power = sum(power_spectrum_dec(b1-win_w:b1+win_w)) + ...
            sum(power_spectrum_dec(b2-win_w:b2+win_w)) + ...
            sum(power_spectrum_dec(b3-win_w:b3+win_w));

noise_power = total_power - sig_power;
sqnr_dec = 10 * log10(sig_power / noise_power);
enob_dec = (sqnr_dec - 1.76) / 6.02;

fprintf('\n=== FINAL STEADY-STATE RESULTS ===\n');
fprintf('Filtered SQNR: %.2f dB\n', sqnr_dec);
fprintf('Filtered ENOB: %.2f bits\n', enob_dec);

%% 5. Plotting Final Baseband
f_axis_dec = (0:N_fft/2-1) * (f_out_target/N_fft);
mag_out_db_dec = 10*log10(power_spectrum_dec / max(power_spectrum_dec));

figure;
plot(f_axis_dec, mag_out_db_dec, 'b', 'LineWidth', 1.2);
grid on; hold on;
xline(1000, 'r--', 'LineWidth', 2, 'Label', '1 kHz Cutoff');
axis([0 (f_out_target/2) -180 0]);
title('Steady-State Baseband Spectrum (CIC + FIR)');
xlabel('Frequency (Hz)');
ylabel('Normalized Magnitude (dB)');