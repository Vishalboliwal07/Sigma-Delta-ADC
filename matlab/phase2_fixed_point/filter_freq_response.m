% =========================================================================
% Items 8 & 9: Final Decimation Filter Frequency Response
% =========================================================================
clear; clc; close all;

%% 1. Parameters
f_s = 512000;         % High-speed modulator clock
f_out = 2000;         % Final Nyquist rate
f_pass = 1000;        % Baseband limit
R = 64; K = 3;        % CIC parameters

% Frequency vector (0 to 16 kHz to show the first few CIC nulls)
f = linspace(0.1, 16000, 10000); 

%% 2. CIC Magnitude Response
% Theoretical CIC response: H(f) = [sin(pi*f*R/fs) / sin(pi*f/fs)]^K / R^K
H_cic = (sin(pi * f * R / f_s) ./ sin(pi * f / f_s)).^K / (R^K);
H_cic_db = 20 * log10(abs(H_cic));

%% 3. FIR Magnitude Response
% Design the inverse-SINC compensation filter exactly as done in the generator script
f_out_cic = f_s / R;  
f_nyquist = f_out_cic / 2; 
F_pass = 1000;        
F_stop = 2000;        

f_vec = [0, F_pass];
H_cic_droop = (sin(pi * f_vec * R / f_s) ./ (R * sin(pi * f_vec / f_s))).^K;
H_cic_droop(1) = 1; 
H_inv = 1 ./ H_cic_droop; 

f_bands = [0, F_pass, F_stop, f_nyquist] / f_nyquist;
a_bands = [H_inv(1), H_inv(2), 0, 0];

% Generate the coefficients using stable fir2
comp_coeffs = fir2(100, f_bands, a_bands);

% Evaluate the frequency response
[H_fir_base, w_fir] = freqz(comp_coeffs, 1, 4096, f_s/R);

% Map the FIR response to our continuous f vector (repeating every 8 kHz)
f_mod = mod(f, f_s/R);
f_mod(f_mod > (f_s/R)/2) = (f_s/R) - f_mod(f_mod > (f_s/R)/2); % Fold around Nyquist
H_fir = interp1(w_fir, abs(H_fir_base), f_mod, 'linear', 'extrap');
H_fir_db = 20 * log10(H_fir);

%% 4. Combined System Response
H_total_db = H_cic_db + H_fir_db;

%% 5. Metric Extraction (Droop & Stopband)
idx_1kHz = find(f >= 1000, 1);
droop_1kHz = H_total_db(idx_1kHz);

idx_4kHz = find(f >= 4000, 1);
stopband_att = H_total_db(idx_4kHz);

fprintf('\n=== Filter Chain Specifications ===\n');
fprintf('Combined Passband Droop at 1 kHz: %.2f dB\n', droop_1kHz);
fprintf('Stopband Attenuation at 4 kHz:   %.2f dB\n', stopband_att);

%% 6. Plotting
figure('Position', [100, 100, 800, 500]);
plot(f, H_cic_db, 'b--', 'LineWidth', 1.5); hold on;
plot(f, H_fir_db, 'r--', 'LineWidth', 1.5);
plot(f, H_total_db, 'k', 'LineWidth', 2);

% Markers
xline(1000, 'g:', 'LineWidth', 1.5, 'Label', '1 kHz Passband');
xline(4000, 'm:', 'LineWidth', 1.5, 'Label', '4 kHz Alias Limit');
plot(1000, droop_1kHz, 'ko', 'MarkerFaceColor', 'y', 'MarkerSize', 8);

grid on;
axis([0 16000 -120 10]);
title('Total Decimation Filter Frequency Response');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
legend('CIC (SINC^3) Only', 'FIR Compensation Only', 'Combined Response', 'Location', 'Southwest');