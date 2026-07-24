% =========================================================================
% Final Sweep Script: Filtered ENOB vs OSR (2nd-Order Delta-Sigma)
% =========================================================================
clear; clc; close all;

%% 1. Sweep Parameters
f_out_target = 2000;              % Target Nyquist output rate (2 ksps)
osr_array = [16, 32, 64, 128, 256]; % OSR operating points
enob_results = zeros(1, length(osr_array));

disp('--- Beginning Multi-Tone Filtered ENOB Sweep ---');

%% 2. Execution Loop
for i = 1:length(osr_array)
    current_OSR = osr_array(i);
    fprintf('Evaluating OSR = %d...\n', current_OSR);
    
    % Call the parameterized ADC function
    enob_results(i) = evaluate_adc_point(f_out_target, current_OSR);
end

disp('Sweep complete. Generating final characterization curve.');

%% 3. Plotting the Post-Filter ENOB-vs-OSR Curve
figure;
semilogx(osr_array, enob_results, '-ob', 'LineWidth', 2, 'MarkerFaceColor', 'b');
grid on; hold on;

% Add Target Boundaries
yline(16, 'r--', 'Target Min (16-bit)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
yline(19, 'g--', 'Target Max (19-bit)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

title('Filtered 2nd-Order \Delta\Sigma ENOB vs OSR (Multi-Tone)');
xlabel('Oversampling Ratio (OSR)');
ylabel('Effective Number of Bits (ENOB)');
xticks(osr_array);
xticklabels(string(osr_array));
axis([min(osr_array) max(osr_array) min(enob_results)-2 20]);

% =========================================================================
% Local Function: Parameterized ADC Behavioral Model & Decimation
% =========================================================================
function enob_dec = evaluate_adc_point(f_out_target, OSR)
    
    % --- Signal Padding & Initialization ---
    f_s = f_out_target * OSR;
    N_fft = 1024;                
    N_transient = 128;           
    N_dec_total = N_fft + N_transient; 
    N_total = N_dec_total * OSR; 
    t = (0:N_total-1) / f_s;     
    
    % --- Coherent Frequencies ---
    f_res = f_out_target / N_fft;
    f1 = 11 * f_res; f2 = 43 * f_res; f3 = 211 * f_res; 
    amp = 0.5 / 3;      
    signal_in = amp*sin(2*pi*f1*t) + amp*sin(2*pi*f2*t) + amp*sin(2*pi*f3*t);
    
    % --- 2nd-Order Modulator ---
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
    
    % --- Dynamic 2-Stage Decimation ---
    R_fir = 4;
    R_cic = OSR / R_fir; % Dynamically scale coarse decimation
    
    % Stage 1: CIC (SINC^3)
    K = 3;
    cic_impulse = ones(1, R_cic);
    filtered_sig = v_out;
    for k = 1:K
        filtered_sig = filter(cic_impulse, 1, filtered_sig); 
    end
    v_out_cic = filtered_sig(1:R_cic:end) / (R_cic^K);
    
    % Stage 2: FIR Compensation
    fir_coeffs = fir1(100, 0.25);

    
    v_out_fir = filter(fir_coeffs, 1, v_out_cic);


    v_out_decimated = v_out_fir(1:R_fir:end);
    
    % --- Steady-State Analysis ---
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
    enob_dec = (sqnr_dec - 1.76) / 6.02;
end
% Export results to CSV for final report table
results_table = table(osr_array', enob_results', 'VariableNames', {'OSR', 'Filtered_ENOB'});
writetable(results_table, 'adc_sweep_results.csv');
disp('Data successfully saved to adc_sweep_results.csv');