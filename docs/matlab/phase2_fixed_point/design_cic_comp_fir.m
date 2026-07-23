% =========================================================================
% Inverse-SINC CIC Compensation FIR Design (Stable fir2 approach)
% =========================================================================
clear; clc; close all;

%% 1. Parameters
f_s = 512000;         % Modulator clock
R = 64; K = 3;        % CIC parameters
f_out_cic = f_s / R;  % Intermediate sample rate (8000 Hz)
f_nyquist = f_out_cic / 2; % 4000 Hz

F_pass = 1000;        % Passband edge
F_stop = 2000;        % Stopband edge (carve out noise before 4kHz folding)

%% 2. Calculate the exact CIC Droop to invert
% Evaluate CIC response at the passband edge to find maximum necessary boost
f_vec = [0, F_pass];
H_cic = (sin(pi * f_vec * R / f_s) ./ (R * sin(pi * f_vec / f_s))).^K;
H_cic(1) = 1; % Fix limit at DC (0 Hz)

% The FIR needs to be the exact inverse of the CIC droop
H_inv = 1 ./ H_cic; 

%% 3. Stable FIR Design (fir2)
% Define frequency bands normalized to Nyquist (0 to 1)
f_bands = [0, F_pass, F_stop, f_nyquist] / f_nyquist;
% Define desired amplitudes: [DC, Passband Edge Boost, Stopband, Nyquist]
a_bands = [H_inv(1), H_inv(2), 0, 0];

% Use fir2 (Frequency Sampling Method) which is immune to singular matrix errors
comp_coeffs = fir2(100, f_bands, a_bands);

%% 4. Quantize to 16-bit Q1.15
scale_factor = 2^15;
quantized_coeffs = round(comp_coeffs * scale_factor);
quantized_coeffs = max(min(quantized_coeffs, 32767), -32768); 

%% 5. Export to .mem for Verilog
hex_coeffs = dec2hex(typecast(int16(quantized_coeffs), 'uint16'), 4);
fileID = fopen('fir_coeffs_comp.mem', 'w');
for i = 1:length(quantized_coeffs)
    fprintf(fileID, '%s\n', hex_coeffs(i,:));
end
fclose(fileID);

fprintf('\nSuccess: True CIC Compensation FIR designed and exported to "fir_coeffs_comp.mem"\n');
fprintf('Required Passband Boost at 1 kHz: +%.2f dB\n', 20*log10(H_inv(2)));