`timescale 1ns / 1ps
`default_nettype none

module tb_hardware_anomaly_detection;

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
    // Clock Generation (50MHz)
    // ---------------------------------------------------------
    always #10 clk = ~clk;

    // ---------------------------------------------------------
    // Task: Send 64-bit Serial Packet
    // ---------------------------------------------------------
    // Feeds bits LSB-first into ui_in[0] while holding bit_valid (ui_in[1]) high
    task send_packet;
        input [63:0] packet;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1) begin
                @(posedge clk);
                ui_in[0] <= packet[i]; // serial_bit
                ui_in[1] <= 1'b1;      // bit_valid
            end
            @(posedge clk);
            ui_in[0] <= 1'b0;
            ui_in[1] <= 1'b0;          // Clear bit_valid
        end
    endtask

    // ---------------------------------------------------------
    // Output Monitor
    // ---------------------------------------------------------
    // Because done_flag and irq_flag are 1-cycle pulses, we monitor 
    // them synchronously rather than waiting blindly in the main thread.
    always @(posedge clk) begin
        if (rst_n && uio_out[0]) begin // uio_out[0] is done_flag
            $display("[%0t] RESULT READY | Score: 0x%h | IRQ Triggered: %b", 
                     $time, uo_out, uio_out[1]);
        end
    end

    // ---------------------------------------------------------
    // Main Stimulus
    // ---------------------------------------------------------
    reg [63:0] test_packet;
    reg [7:0]  test_velocity; // Maps to packet_data[31:24]
    reg [7:0]  test_heading;  // Maps to packet_data[23:16]

    initial begin
        // Initialize Inputs
        ui_in  = 8'd0;
        uio_in = 8'd0;
        ena    = 1'b0;
        clk    = 1'b0;
        rst_n  = 1'b0;
        test_packet = 64'd0;

        // VCD Dump for waveform viewing (e.g., in GTKWave)
        $dumpfile("tb_anomaly_detection.vcd");
        $dumpvars(0, tb_hardware_anomaly_detection);

        // Reset Sequence
        #50;
        rst_n = 1'b1;
        #50;

        $display("--- Starting Hardware Anomaly Detection Tests ---");

        // ---------------------------------------------------------
        // TEST 1: SAFE (Target Score: 0x00)
        // Equation: 12 * 10 + 88 * 5 = 560 (< 1024)
        // ---------------------------------------------------------
        test_velocity = 8'd10;
        test_heading  = 8'd5;
        test_packet[31:24] = test_velocity;
        test_packet[23:16] = test_heading;
        
        $display("\nSending Test 1 (SAFE)...");
        send_packet(test_packet);
        repeat(10) @(posedge clk); // Wait for pipeline stages to flush

        // ---------------------------------------------------------
        // TEST 2: CAUTION (Target Score: 0x55)
        // Equation: 12 * 50 + 88 * 10 = 1480 (>= 1024)
        // ---------------------------------------------------------
        test_velocity = 8'd50;
        test_heading  = 8'd10;
        test_packet[31:24] = test_velocity;
        test_packet[23:16] = test_heading;
        
        $display("\nSending Test 2 (CAUTION)...");
        send_packet(test_packet);
        repeat(10) @(posedge clk);

        // ---------------------------------------------------------
        // TEST 3: WARNING (Target Score: 0xAA)
        // Equation: 12 * 100 + 88 * 15 = 2520 (>= 2048)
        // ---------------------------------------------------------
        test_velocity = 8'd100;
        test_heading  = 8'd15;
        test_packet[31:24] = test_velocity;
        test_packet[23:16] = test_heading;
        
        $display("\nSending Test 3 (WARNING)...");
        send_packet(test_packet);
        repeat(10) @(posedge clk);

        // ---------------------------------------------------------
        // TEST 4: CRITICAL (Target Score: 0xFF, IRQ: 1)
        // Equation: 12 * 120 + 88 * 40 = 4960 (>= 4096)
        // ---------------------------------------------------------
        test_velocity = 8'd120;
        test_heading  = 8'd40;
        test_packet[31:24] = test_velocity;
        test_packet[23:16] = test_heading;
        
        $display("\nSending Test 4 (CRITICAL)...");
        send_packet(test_packet);
        repeat(10) @(posedge clk);

        // ---------------------------------------------------------
        // End Simulation
        // ---------------------------------------------------------
        #100;
        $display("\n--- Tests Complete ---");
        $finish;
    end

endmodule
