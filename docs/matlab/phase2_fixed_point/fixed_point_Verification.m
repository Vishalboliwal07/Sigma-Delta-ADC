%% FIR Fixed-Point Quantization Test
clear; clc; close all;

% Design the ideal floating-point filter
fir_order = 100;
Wn = 0.25; 
ideal_coeffs = fir1(fir_order, Wn);

% Quantize to 16-bit (Q1.15 format)
% 15 bits for the fraction means we multiply by 2^15 and round to nearest integer
fractional_bits = 15;
scale_factor = 2^fractional_bits;

% Round and constrain to 16-bit signed integer limits (-32768 to 32767)
quantized_coeffs = round(ideal_coeffs * scale_factor);
quantized_coeffs = max(min(quantized_coeffs, 32767), -32768);

% Convert back to decimal to simulate the fixed-point math in MATLAB
simulated_fixed_coeffs = quantized_coeffs / scale_factor;

% Plot the frequency response comparison
figure;
[H_ideal, w_ideal] = freqz(ideal_coeffs, 1, 1024, 8000);
[H_fixed, w_fixed] = freqz(simulated_fixed_coeffs, 1, 1024, 8000);

plot(w_ideal, 20*log10(abs(H_ideal)), 'b', 'LineWidth', 1.5); hold on;
plot(w_fixed, 20*log10(abs(H_fixed)), 'r--', 'LineWidth', 1.5);
grid on;
title('FIR Filter: Floating-Point vs 16-bit Fixed-Point');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
legend('Ideal (64-bit Float)', 'Quantized (16-bit Q1.15)');
axis([0 4000 -120 10]);