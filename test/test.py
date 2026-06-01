# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly

async def send_packet(dut, velocity, heading):
    """
    Helper coroutine to serialize and send a 64-bit packet.
    Velocity maps to bits 31:24, Heading maps to bits 23:16.
    """
    # Construct the 64-bit integer
    packet = (velocity << 24) | (heading << 16)
    
    for i in range(64):
        # Shift out LSB first
        bit = (packet >> i) & 1
        
        # ui_in[0] = serial_bit, ui_in[1] = bit_valid (value 2)
        dut.ui_in.value = bit | 0b00000010 
        await ClockCycles(dut.clk, 1)
        
    # Clear pins after packet is sent
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

async def wait_for_result(dut):
    """
    Helper coroutine to wait for the done_flag pulse and capture outputs.
    """
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly() # Wait until signals settle for this clock cycle
        
        # Check if uio_out[0] (done_flag) is HIGH
        uio_val = int(dut.uio_out.value)
        if (uio_val & 0b00000001) != 0:
            score = int(dut.uo_out.value)
            irq_triggered = (uio_val & 0b00000010) != 0 # Check uio_out[1]
            
            # --- THE FIX: Step out of ReadOnly phase before returning! ---
            await RisingEdge(dut.clk) 
            
            return score, irq_triggered

@cocotb.test()
async def test_anomaly_detection(dut):
    dut._log.info("Starting Hardware Anomaly Detection Testbench")

    # Set the clock period to 20 ns (50 MHz)
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # ---------------------------------------------------------
    # RESET SEQUENCE
    # ---------------------------------------------------------
    dut._log.info("Applying Reset...")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # ---------------------------------------------------------
    # TEST 1: SAFE (Target 0x00)
    # 12*10 + 88*5 = 560 (< 1024)
    # ---------------------------------------------------------
    dut._log.info("Sending Test 1: SAFE...")
    await send_packet(dut, velocity=10, heading=5)
    score, irq = await wait_for_result(dut)
    
    dut._log.info(f"Result -> Score: {hex(score)}, IRQ: {irq}")
    assert score == 0x00, f"Test 1 Failed: Expected 0x00, got {hex(score)}"
    assert not irq, "Test 1 Failed: IRQ should not trigger on SAFE"

    # ---------------------------------------------------------
    # TEST 2: CAUTION (Target 0x55)
    # 12*50 + 88*10 = 1480 (>= 1024)
    # ---------------------------------------------------------
    dut._log.info("Sending Test 2: CAUTION...")
    await send_packet(dut, velocity=50, heading=10)
    score, irq = await wait_for_result(dut)
    
    dut._log.info(f"Result -> Score: {hex(score)}, IRQ: {irq}")
    assert score == 0x55, f"Test 2 Failed: Expected 0x55, got {hex(score)}"
    assert not irq, "Test 2 Failed: IRQ should not trigger on CAUTION"

    # ---------------------------------------------------------
    # TEST 3: WARNING (Target 0xAA)
    # 12*100 + 88*15 = 2520 (>= 2048)
    # ---------------------------------------------------------
    dut._log.info("Sending Test 3: WARNING...")
    await send_packet(dut, velocity=100, heading=15)
    score, irq = await wait_for_result(dut)
    
    dut._log.info(f"Result -> Score: {hex(score)}, IRQ: {irq}")
    assert score == 0xAA, f"Test 3 Failed: Expected 0xAA, got {hex(score)}"
    assert not irq, "Test 3 Failed: IRQ should not trigger on WARNING"

    # ---------------------------------------------------------
    # TEST 4: CRITICAL (Target 0xFF)
    # 12*120 + 88*40 = 4960 (>= 4096)
    # ---------------------------------------------------------
    dut._log.info("Sending Test 4: CRITICAL...")
    await send_packet(dut, velocity=120, heading=40)
    score, irq = await wait_for_result(dut)
    
    dut._log.info(f"Result -> Score: {hex(score)}, IRQ: {irq}")
    assert score == 0xFF, f"Test 4 Failed: Expected 0xFF, got {hex(score)}"
    assert irq, "Test 4 Failed: IRQ MUST trigger on CRITICAL"

    dut._log.info("All Hardware Anomaly Detection tests passed successfully!")
