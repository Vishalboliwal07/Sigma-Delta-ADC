% =========================================================================
% Phase 4: Final RTL Performance Evaluation (Corrected)
% =========================================================================
clear; clc; close all;

%% 1. Parameters & Data Loading
f_s = 512000;       % Master clock (512 kHz)
R = 64;             % CIC Decimation Factor
f_s_out = f_s / R;  % Actual RTL Output Rate = 8000 Hz
f_sig = 250;        % Target test tone

rtl_file_path = 'C:\Users\visha\adc\adc.sim\sim_1\behav\xsim\rtl_output.txt';

if ~isfile(rtl_file_path)
    error('Could not find rtl_output.txt at the specified Vivado path. Did you run the simulation?');
end
rtl_data = load(rtl_file_path);
rtl_data = rtl_data(:); % Ensure column vector

% Crop initial transient startup cycles
transient_samples = 150; 
if length(rtl_data) > transient_samples
    rtl_data = rtl_data(transient_samples:end);
else
    error('Not enough data in rtl_output.txt. Run Verilog simulation longer.');
end

fprintf('Loaded %d valid output samples from RTL.\n', length(rtl_data));

%% 2. DC Removal & Windowing (The crucial fix)
% Normalize RTL data
rtl_normalized = rtl_data / (2^19); 

% CRITICAL: Remove the hardware DC bias before windowing to prevent spectral leakage
rtl_normalized = rtl_normalized - mean(rtl_normalized); 

nfft = 8192; % FFT size (power of 2)

% Apply a Blackman-Harris window
win = blackmanharris(length(rtl_normalized));
rtl_windowed = rtl_normalized .* win;

%% 3. FFT Computation
V_fft = fft(rtl_windowed, nfft);
V_fft_mag = abs(V_fft(1:nfft/2+1)); % Single-sided spectrum
V_fft_mag = V_fft_mag / max(V_fft_mag); % Normalize peak to 0 dBFS

PSD_dB = 20 * log10(V_fft_mag + eps);
f_axis = linspace(0, f_s_out/2, nfft/2+1);

%% 4. Calculate SQNR and ENOB
[~, signal_bin] = max(V_fft_mag);

% Widen the signal bandwidth to capture the full Blackman-Harris main lobe
signal_bw = 12; 
signal_bins = max(1, signal_bin - signal_bw) : min(length(V_fft_mag), signal_bin + signal_bw);

signal_power = sum(V_fft_mag(signal_bins).^2);

% Calculate Noise Power (Exclude DC completely and Signal)
noise_bins = true(size(V_fft_mag));
noise_bins(1:5) = false;         % Strip out residual DC bins
noise_bins(signal_bins) = false; % Strip out signal bins
noise_power = sum(V_fft_mag(noise_bins).^2);

% Compute SQNR & ENOB
SQNR_dB = 10 * log10(signal_power / noise_power);
ENOB = (SQNR_dB - 1.76) / 6.02;

%% 5. Results & Plotting
fprintf('\n=== FINAL RTL HARDWARE PERFORMANCE ===\n');
fprintf('Measured SQNR : %.2f dB\n', SQNR_dB);
fprintf('Calculated ENOB: %.2f Bits\n', ENOB);

figure('Position', [100, 100, 800, 500]);
plot(f_axis, PSD_dB, 'b', 'LineWidth', 1.5); hold on;
plot(f_axis(signal_bin), PSD_dB(signal_bin), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on;

% Formatting
axis([0 f_s_out/2 -140 10]);
title(sprintf('Verilog RTL Power Spectral Density (ENOB = %.2f Bits)', ENOB));
xlabel('Frequency (Hz)');
ylabel('Magnitude (dBFS)');
legend('RTL Output Spectrum', 'Fundamental Frequency', 'Location', 'Northeast');
yline(-98, 'r--', '16-Bit Ideal Noise Floor (-98 dBFS)', 'LabelHorizontalAlignment', 'left');