`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2026 23:24:51
// Design Name: 
// Module Name: tb_adc_backend
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




module tb_adc_backend;

    // --- Signals ---
    reg         clk;
    reg         rst_n;
    reg         din;
    wire        valid_out;
    wire [19:0] dout;

    // --- File Handles ---
    integer     file_in;
    integer     file_out;
    integer     scan_status;
    reg [31:0]  stimulus_bit; // Buffer for reading file

    // --- DUT Instantiation ---
    adc_backend_top u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .valid_out(valid_out),
        .dout(dout)
    );

    // --- Clock Generation (512 kHz -> ~1953 ns period) ---
    // For functional simulation, a simple 10ns period is fine since 
    // the logic is strictly synchronous, but we'll stick to a clean 10ns for speed.
    always #5 clk = ~clk;

    // --- Test Sequence ---
    initial begin
        // Initialize Signals
        clk   = 0;
        rst_n = 0;
        din   = 0;

        // Open Stimulus and Output files
        file_in  = $fopen("C:/Users/visha/Downloads/modulator_out.txt", "r");
        file_out = $fopen("rtl_output.txt", "w");

        if (file_in == 0) begin
            $display("ERROR: Could not open modulator_out.txt");
            $finish;
        end

        // Apply Reset
        #100;
        rst_n = 1;
        $display("Reset released. Beginning data pipeline...");
        $display("Waiting for CIC + FIR pipeline latency (3,295 clock cycles)...");

        // Feed data cycle-by-cycle
        while (!$feof(file_in)) begin
            scan_status = $fscanf(file_in, "%b\n", stimulus_bit);
            if (scan_status == 1) begin
                din = stimulus_bit[0];
            end
            @(posedge clk);
        end

        // Close files and end simulation
        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation Complete. Output written to rtl_output.txt");
        $finish;
    end

    // --- Output Capture Logic ---
    // This perfectly isolates the valid 2 ksps data and writes it to the output file
    always @(posedge clk) begin
        if (valid_out && rst_n) begin
            // Write the 20-bit two's complement integer to the text file
            $fdisplay(file_out, "%d", $signed(dout));
        end
    end

endmodule
