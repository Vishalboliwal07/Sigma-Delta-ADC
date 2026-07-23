`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:20:57
// Design Name: 
// Module Name: adc_backend_top
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



module adc_backend_top (
    input  wire        clk,        // Master high-speed clock (512 kHz)
    input  wire        rst_n,      // Active-low synchronous reset
    input  wire        din,        // 1-bit input from Delta-Sigma modulator
    output wire        valid_out,  // High for 1 cycle when final 20-bit FIR data is ready (2 ksps rate)
    output wire [19:0] dout        // 20-bit final rounded output
);

    // --- Internal Interconnect Wires ---
    // These carry the intermediate 8 kHz data and handshaking signals
    // from the CIC block to the FIR block.
    wire        cic_valid_out;
    wire [18:0] cic_data_out;

    // --- 1. CIC Coarse Decimator (R=64, SINC^3) ---
    cic_top u_cic (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .valid_out(cic_valid_out),
        .dout(cic_data_out)
    );

    // --- 2. FIR Compensation Filter (Folded MAC) ---
    fir_compensation_stage u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(cic_valid_out),
        .din(cic_data_out),
        .valid_out(valid_out),
        .dout(dout)
    );

endmodule
