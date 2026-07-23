`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:10:19
// Design Name: 
// Module Name: cic_integrator_stage
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

module cic_integrator_stage (
    input  wire        clk,      // High-speed modulator clock (512 kHz)
    input  wire        rst_n,    // Active-low synchronous reset
    input  wire        din,      // 1-bit input from modulator (1 = +1, 0 = -1)
    output wire [18:0] dout      // 19-bit output to the decimation/comb stage
);

    // Internal 19-bit registers for the 3 cascaded integrators
    reg [18:0] int1;
    reg [18:0] int2;
    reg [18:0] int3;

    // Map the 1-bit Delta-Sigma input into 19-bit Two's Complement
    // din = 1 maps to +1 (19'h00001)
    // din = 0 maps to -1 (19'h7FFFF)
    wire [18:0] din_mapped = din ? 19'h00001 : 19'h7FFFF;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int1 <= 19'd0;
            int2 <= 19'd0;
            int3 <= 19'd0;
        end else begin
            // Stage 1: Add mapped input to previous accumulator state
            int1 <= int1 + din_mapped;
            
            // Stage 2: Add Stage 1 output to previous accumulator state
            int2 <= int2 + int1;
            
            // Stage 3: Add Stage 2 output to previous accumulator state
            int3 <= int3 + int2;
        end
    end

    // Continuously drive the final integrator value to the output
    assign dout = int3;

endmodule
