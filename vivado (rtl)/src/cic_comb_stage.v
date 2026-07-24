`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:12:07
// Design Name: 
// Module Name: cic_comb_stage
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



module cic_comb_stage (
    input  wire        clk,        // High-speed clock (512 kHz)
    input  wire        rst_n,      // Active-low synchronous reset
    input  wire [18:0] din,        // 19-bit output from the integrator stage
    output reg         valid_out,  // High for 1 clock cycle when new data is ready
    output wire [18:0] dout        // 19-bit decimated and combed output
);

    parameter R = 64; // Decimation factor

    // --- Downsampler Counter ---
    reg [5:0] count; // 6-bit counter for 0 to 63
    wire dec_en = (count == R - 1); // Enable pulse every 64th cycle

    // --- Comb Stage Registers ---
    // We need memory to hold the delayed values (z^-1)
    reg [18:0] delay1, delay2, delay3;
    reg [18:0] comb1,  comb2,  comb3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= 6'd0;
            valid_out <= 1'b0;
            delay1    <= 19'd0;
            delay2    <= 19'd0;
            delay3    <= 19'd0;
            comb1     <= 19'd0;
            comb2     <= 19'd0;
            comb3     <= 19'd0;
        end else begin
            // 1. Clock Divider Logic
            if (dec_en) begin
                count     <= 6'd0;
                valid_out <= 1'b1; // Flag to the FIR filter that data is ready
            end else begin
                count     <= count + 1'b1;
                valid_out <= 1'b0;
            end

            // 2. Comb Filter Logic (Only executes when dec_en is HIGH)
            if (dec_en) begin
                // Stage 1: Current input minus previous input
                delay1 <= din;
                comb1  <= din - delay1;
                
                // Stage 2: Current comb1 minus previous comb1
                delay2 <= comb1;
                comb2  <= comb1 - delay2;
                
                // Stage 3: Current comb2 minus previous comb2
                delay3 <= comb2;
                comb3  <= comb2 - delay3;
            end
        end
    end

    // Continuously drive the final comb value to the output
    assign dout = comb3;

endmodule
