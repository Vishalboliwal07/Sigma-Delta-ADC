`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:17:59
// Design Name: 
// Module Name: fir_compensation_stage
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fir_compensation_stage (
    input  wire        clk,        // Master high-speed clock (512 kHz)
    input  wire        rst_n,      // Active-low synchronous reset
    input  wire        valid_in,   // High for 1 cycle when CIC data is ready
    input  wire [18:0] din,        // 19-bit data from CIC
    output reg         valid_out,  // High for 1 cycle when FIR data is rounded and ready
    output reg  [19:0] dout        // 20-bit final rounded output
);

    // --- 1. Memory and Coefficients ---
    reg signed [18:0] shift_reg [0:100]; // 101-tap delay line
    reg signed [15:0] coeffs [0:50];     // 51 unique symmetric coefficients
    
    // Load the 16-bit Q1.15 coefficients exported from MATLAB[cite: 2, 4]
    initial begin
        $readmemh("fir_coeffs_comp.mem", coeffs);
    end

    // --- 2. Internal Registers ---
    reg signed [34:0] mac_acc;           // 35-bit internal accumulator
    reg [5:0]         state;             // State machine counter (0 to 63)
    reg               processing;        // Flag to indicate active MAC operation

    integer i;

    // --- 3. Folded MAC State Machine ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out  <= 1'b0;
            dout       <= 20'd0;
            mac_acc    <= 35'd0;
            state      <= 6'd0;
            processing <= 1'b0;
            
            for (i = 0; i <= 100; i = i + 1) begin
                shift_reg[i] <= 19'd0;
            end
        end else begin
            // Default: clear output flag
            valid_out <= 1'b0;

            // Triggered by the CIC valid signal
            if (valid_in) begin
                // Shift the delay line
                for (i = 100; i > 0; i = i - 1) begin
                    shift_reg[i] <= shift_reg[i-1];
                end
                shift_reg[0] <= $signed(din);
                
                // Start the MAC engine
                processing <= 1'b1;
                state      <= 6'd0;
                mac_acc    <= 35'd0;
            end
            
            else if (processing) begin
                if (state < 50) begin
                    // Taps 0 to 49 (Symmetric Fold)
                    // Add symmetric data points, multiply by shared coefficient, and accumulate
                    mac_acc <= mac_acc + (($signed(shift_reg[state]) + $signed(shift_reg[100 - state])) * $signed(coeffs[state]));
                    state   <= state + 1'b1;
                end 
                else if (state == 50) begin
                    // Center Tap 50 (No symmetry pair)
                    mac_acc <= mac_acc + ($signed(shift_reg[50]) * $signed(coeffs[50]));
                    state   <= state + 1'b1;
                end 
                else if (state == 51) begin
                    // Output Formatting Phase: Hardware Rounding and Truncation[cite: 8]
                    // Add 2^14 (35'h04000) for round-to-nearest[cite: 8]
                    mac_acc <= mac_acc + 35'h04000;
                    state   <= state + 1'b1;
                end
                else if (state == 52) begin
                    // Arithmetic right shift by 15 bits, grab the bottom 20 bits[cite: 8]
                    dout       <= mac_acc[34:15]; 
                    valid_out  <= 1'b1; // Pulse valid_out for the testbench/next stage
                    processing <= 1'b0; // Stop MAC engine until next valid_in
                end
            end
        end
    end

endmodule
