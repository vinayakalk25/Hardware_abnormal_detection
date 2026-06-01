`timescale 1ns / 1ps
`default_nettype none

module tb_hardware_anomaly_detectio;

    // ---------------------------------------------------------
    // Signal Declarations
    // ---------------------------------------------------------
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    reg        ena;
    reg        clk;
    reg        rst_n;

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ---------------------------------------------------------
    // UUT Instantiation
    // ---------------------------------------------------------
    tt_um_hardware_anomaly_detection uut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // ---------------------------------------------------------
    // VCD Waveform Dumping
    // ---------------------------------------------------------
    // All actual stimulus and testing is handled by Python (test.py)
    initial begin
        $dumpfile("tb_anomaly_detection.vcd");
        $dumpvars(0, tb_hardware_anomaly_detection);
        #1;
    end

endmodule
