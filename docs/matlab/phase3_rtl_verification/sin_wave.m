% =========================================================================
% Phase 4.1: Sine Wave Stimulus Generator
% =========================================================================
clear; clc;

f_s = 512000;       % 512 kHz sample rate
N_total = 512000;   % 1 second of data
f_sig = 250;        % 250 Hz pure sine wave

fprintf('Generating 250 Hz sine wave stimulus...\n');

% 1. Create the pure sine wave (Amplitude 0.5 to avoid clipping)
t = (0:N_total-1) / f_s;
signal_in = 0.5 * sin(2 * pi * f_sig * t);

% 2. Run the pure sine wave through the Delta-Sigma Modulator
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

% 3. Convert to binary and write to your Downloads folder
din_binary = (v_out > 0); 
stimulus_file = 'C:\Users\visha\Downloads\modulator_out.txt';

fileID = fopen(stimulus_file, 'w');
if fileID == -1
    error('Could not open file. Check if the directory exists and is writable.');
end
fprintf(fileID, '%d\n', din_binary);
fclose(fileID);

fprintf('SUCCESS: Wrote 250 Hz Sine Wave to %s\n', stimulus_file);
fprintf('-> ACTION REQUIRED: Go to Vivado, hit Reset, and click "Run All" now.\n');