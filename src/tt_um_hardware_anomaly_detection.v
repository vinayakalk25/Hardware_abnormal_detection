`timescale 1ns / 1ps
`default_nettype none

module tt_um_hardware_anomaly_detection (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // =====================================================================
    // INPUT PIN MAPPING
    // =====================================================================
    wire serial_bit   = ui_in[0];   // Serial V2X input (LSB first)
    wire bit_valid    = ui_in[1];   // Bit valid strobe
    wire mode_sel     = ui_in[2];   // Mode selection (reserved)
    // ui_in[3:7] unused

    // =====================================================================
    // LAYER 1: SIPO INGESTION (Serial-to-Parallel)
    // =====================================================================
    reg [63:0] packet_data;
    reg [5:0]  bit_counter;
    reg        packet_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_data  <= 64'd0;
            bit_counter  <= 6'd0;
            packet_ready <= 1'b0;
        end
        else begin
            packet_ready <= 1'b0;  // Default: pulse once
            
            if (bit_valid) begin
                // Shift in new bit (LSB first)
                packet_data <= {serial_bit, packet_data[63:1]};
                
                if (bit_counter == 6'd63) begin
                    // 64 bits received, packet complete
                    bit_counter  <= 6'd0;
                    packet_ready <= 1'b1;
                end
                else begin
                    bit_counter <= bit_counter + 1'b1;
                end
            end
        end
    end

    // =====================================================================
    // LAYER 2: FEATURE EXTRACTOR (Combinational)
    // =====================================================================
    wire signed [7:0] node_x0 = packet_data[31:24];  // Velocity
    wire signed [7:0] node_x1 = packet_data[23:16];  // Heading

    // =====================================================================
    // LAYER 3: DMA FLOW CONTROL (Register for pipelining)
    // =====================================================================
    reg [7:0] x0_pipe;
    reg [7:0] x1_pipe;
    reg       dma_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x0_pipe   <= 8'd0;
            x1_pipe   <= 8'd0;
            dma_valid <= 1'b0;
        end
        else begin
            if (packet_ready) begin
                x0_pipe   <= node_x0;
                x1_pipe   <= node_x1;
                dma_valid <= 1'b1;
            end
            else begin
                dma_valid <= 1'b0;
            end
        end
    end

    // =====================================================================
    // LAYER 4: ML INFERENCE CORE (Systolic Array - 2x2 MACs)
    // =====================================================================
    reg signed [15:0] mac_result;
    reg               mac_valid;

    // Hardcoded weights from trained model
    localparam signed [7:0] W00 = 8'd12;   // velocity -> neuron_0
    localparam signed [7:0] W01 = 8'd88;   // heading -> neuron_0
    localparam signed [7:0] W10 = -8'd5;   // velocity -> neuron_1
    localparam signed [7:0] W11 = 8'd22;   // heading -> neuron_1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_result <= 16'd0;
            mac_valid  <= 1'b0;
        end
        else begin
            if (dma_valid) begin
                // MAC computation: 12*velocity + 88*heading
                mac_result <= ($signed(x0_pipe) * W00) + 
                              ($signed(x1_pipe) * W01);
                mac_valid <= 1'b1;
            end
            else begin
                mac_valid <= 1'b0;
            end
        end
    end

    // =====================================================================
    // LAYER 5: ANOMALY SCORING ENGINE (Threat Classification)
    // =====================================================================
    wire signed [15:0] relu_output = (mac_result > 16'sd0) ? mac_result : 16'sd0;

    reg [7:0] final_score;
    reg       score_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_score <= 8'h00;
            score_valid <= 1'b0;
        end
        else begin
            if (mac_valid) begin
                // Threshold-based threat classification
                if (relu_output >= 16'd4096)          // CRITICAL
                    final_score <= 8'hFF;
                else if (relu_output >= 16'd2048)     // WARNING
                    final_score <= 8'hAA;
                else if (relu_output >= 16'd1024)     // CAUTION
                    final_score <= 8'h55;
                else                                   // SAFE
                    final_score <= 8'h00;
                
                score_valid <= 1'b1;
            end
            else begin
                score_valid <= 1'b0;
            end
        end
    end

    // =====================================================================
    // LAYER 6: OUTPUT ENDPOINTS (Alert & Interrupt Generation)
    // =====================================================================
    reg done_flag;
    reg irq_flag;
    reg uart_tx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_flag <= 1'b0;
            irq_flag  <= 1'b0;
            uart_tx   <= 1'b0;
        end
        else begin
            // Default: single-cycle pulses
            done_flag <= 1'b0;
            irq_flag  <= 1'b0;

            if (score_valid) begin
                done_flag <= 1'b1;                    // Pulse HIGH for 1 cycle
                
                // Interrupt on critical threat
                if (final_score >= 8'hC0)             // ATTACK threshold
                    irq_flag <= 1'b1;                 // Pulse HIGH for 1 cycle
                
                // Optional UART telemetry (send full score)
                uart_tx <= 1'b0;  // Can extend for real UART protocol
            end
        end
    end

    // =====================================================================
    // OUTPUT PIN ASSIGNMENT
    // =====================================================================
    assign uo_out[7:0] = final_score;              // 8-bit threat level
    
    assign uio_out[0]  = done_flag;                // Packet complete pulse
    assign uio_out[1]  = irq_flag;                 // Interrupt request pulse
    assign uio_out[2]  = uart_tx;                  // UART telemetry (optional)
    assign uio_out[7:3] = 5'b0;                    // Unused outputs

    // =====================================================================
    // TRISTATE CONTROL
    // =====================================================================
    assign uio_oe = 8'b0000_0111;                  // Enable pins 0, 1, 2 as outputs

    // =====================================================================
    // UNUSED INPUTS (Avoid warnings)
    // =====================================================================
    wire _unused = &{ena, mode_sel, uio_in, 1'b0};

endmodule

`default_nettype wire
