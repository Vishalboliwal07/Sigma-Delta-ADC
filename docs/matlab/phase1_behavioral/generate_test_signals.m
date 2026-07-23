% =========================================================================
% Multi-Tone Signal Generator for 2nd-Order Delta-Sigma ADC
% =========================================================================
clear; clc; close all;

%% 1. Target Specifications
f_out_target = 2000;         % Target Nyquist output rate (2 ksps)
f_band = f_out_target / 2;   % Signal bandwidth (1 kHz)
OSR = 256;                   % Target Oversampling Ratio
f_s = f_out_target * OSR;    % Modulator sampling frequency (512 kHz)

%% 2. Multi-Tone Generation
% Choosing frequencies within the 1 kHz bandwidth that are mutually prime
% to prevent harmonic overlap during the FFT analysis.
f1 = 113; % Hz
f2 = 331; % Hz
f3 = 701; % Hz

% Time vector based on coherent sampling for a clean FFT
N_samples = 2^18;            % 262,144 samples
t = (0:N_samples-1) / f_s;   % Time vector definition

% Generate half-scale amplitude to prevent modulator overload 
% (Amplitude = 0.5 total, split across three tones)
amp_per_tone = 0.5 / 3;
signal_in = amp_per_tone * sin(2*pi*f1*t) + ...
            amp_per_tone * sin(2*pi*f2*t) + ...
            amp_per_tone * sin(2*pi*f3*t);

%% 3. Plotting the Input Signal
figure;
subplot(2,1,1);
plot(t(1:1000), signal_in(1:1000), 'LineWidth', 1.5);
grid on;
title('Time Domain: Multi-Tone Input Signal');
xlabel('Time (s)');
ylabel('Amplitude');

% Quick FFT to verify the spectrum
window = blackmanharris(N_samples)';
signal_windowed = signal_in .* window;
fft_sig = fft(signal_windowed);
mag_sig = 20*log10(abs(fft_sig(1:N_samples/2)) / (N_samples/2));
f_axis = (0:N_samples/2-1) * (f_s/N_samples);

subplot(2,1,2);
semilogx(f_axis, mag_sig, 'LineWidth', 1.2);
grid on; hold on;
xline(f_band, 'r--', 'LineWidth', 1.5); % Mark the 1 kHz bandwidth limit
axis([10 (f_s/2) -120 0]);
title('Frequency Domain: Input Spectrum');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
legend('Signal', 'Target Bandwidth Limit');

disp('Test vectors generated successfully. Ready for Simulink.');

% Format for Simulink "From Workspace" block (column vectors)
simin = [t', signal_in']; 
disp('simin array created for Simulink.');