% =========================================================================
% Precision Floor Sweep: OSR=256 at 8, 10, 12, 14, 16 bits
% =========================================================================
clear; clc;

% --- 1. Target Setup (OSR=256) ---
f_out_target = 2000; OSR = 256; f_s = f_out_target * OSR;
N_fft = 1024; N_transient = 128; N_total = (N_fft + N_transient) * OSR; 
t = (0:N_total-1) / f_s;     
    
f_res = f_out_target / N_fft;
f1 = 11 * f_res; f2 = 43 * f_res; f3 = 211 * f_res; 
amp = 0.5 / 3;      
signal_in = amp*sin(2*pi*f1*t) + amp*sin(2*pi*f2*t) + amp*sin(2*pi*f3*t);
    
% --- 2. 2nd-Order Modulator ---
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
    
% --- 3. CIC Decimation (SINC^3) ---
R_fir = 4; R_cic = OSR / R_fir; K = 3;
cic_impulse = ones(1, R_cic);
filtered_sig = v_out;
for k = 1:K
    filtered_sig = filter(cic_impulse, 1, filtered_sig); 
end
v_out_cic = filtered_sig(1:R_cic:end) / (R_cic^K);

% --- 4. FIR Precision Sweep ---
ideal_coeffs = fir1(100, 0.25);
v_out_fir_ideal = filter(ideal_coeffs, 1, v_out_cic);
enob_ideal = calc_enob(v_out_fir_ideal(1:R_fir:end), N_fft);

bit_widths = [8, 10, 12, 14, 16];
fprintf('\n--- FIR Precision Floor (OSR=256) ---\n');
fprintf('Ideal (64-bit float): %.4f bits ENOB\n\n', enob_ideal);
fprintf('%-10s | %-12s | %-12s\n', 'FIR Width', 'Quant. ENOB', 'Degradation');
fprintf('---------------------------------------\n');

for w = bit_widths
    frac_bits = w - 1;
    scale = 2^frac_bits;
    q_coeffs = round(ideal_coeffs * scale);
    q_coeffs = max(min(q_coeffs, 2^(w-1)-1), -2^(w-1));
    sim_coeffs = q_coeffs / scale;
    
    v_out_fir_q = filter(sim_coeffs, 1, v_out_cic);
    enob_q = calc_enob(v_out_fir_q(1:R_fir:end), N_fft);
    
    fprintf('%-10d | %-12.4f | %-12.4f\n', w, enob_q, enob_ideal - enob_q);
end

% Local Helper for ENOB
function enob = calc_enob(v_out_decimated, N_fft)
    v_out_steady = v_out_decimated(end - N_fft + 1 : end);
    v_out_steady = v_out_steady - mean(v_out_steady); 
    window_dec = blackmanharris(N_fft)';
    power_spec = abs(fft(v_out_steady .* window_dec)).^2;
    power_spec = power_spec(1:N_fft/2);
    
    total_power = sum(power_spec(3:end)); 
    b1=12; b2=44; b3=212; win=4; % 1-indexed bins
    sig_power = sum(power_spec(b1-win:b1+win)) + sum(power_spec(b2-win:b2+win)) + sum(power_spec(b3-win:b3+win));
    sqnr = 10 * log10(sig_power / (total_power - sig_power));
    enob = (sqnr - 1.76) / 6.02;
end