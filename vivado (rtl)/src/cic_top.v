`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:13:58
// Design Name: 
// Module Name: cic_top
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



module cic_top (
    input  wire        clk,        // Master high-speed clock (512 kHz)
    input  wire        rst_n,      // Active-low synchronous reset
    input  wire        din,        // 1-bit input from Delta-Sigma modulator
    output wire        valid_out,  // Handshake flag: High for 1 cycle when 8 kHz output is ready
    output wire [18:0] dout        // 19-bit final CIC output
);

    // Internal wire to carry the highly-overflowed 19-bit data 
    // from the integrator stage to the comb stage
    wire [18:0] int_to_comb_data;

    // --- Instantiate the Integrator Stage ---
    cic_integrator_stage u_integrator (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(int_to_comb_data)
    );

    // --- Instantiate the Downsampler & Comb Stage ---
    cic_comb_stage u_comb (
        .clk(clk),
        .rst_n(rst_n),
        .din(int_to_comb_data),
        .valid_out(valid_out),
        .dout(dout)
    );

endmodule
