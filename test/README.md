# Hardware Anomaly Detection - Testbench Setup

This directory contains the simulation environment for the **Hardware Anomaly Detection** Tiny Tapeout project. 

Because this project utilizes a highly specific serial-ingestion pipeline, we use a custom, self-checking Verilog testbench (`tb.v`) to drive the 64-bit V2X packets. However, to maintain compatibility with the Tiny Tapeout GitHub Actions flow, we use a minimal [cocotb](https://docs.cocotb.org/en/stable/) script (`test.py`) that simply launches the simulation and waits for the Verilog testbench to complete its work.

For more information on the standard testing flow, check the [Tiny Tapeout testing documentation](https://tinytapeout.com/hdl/testing/).

## Project Files

* **`tb.v`**: The self-checking Verilog testbench. It generates a 50MHz clock, handles the reset sequence, and feeds four distinct test packets (SAFE, CAUTION, WARNING, CRITICAL) serially into the DUT.
* **`test.py`**: A minimal Cocotb wrapper. It does not drive pins directly; instead, it waits for `1500 ns` to allow `tb.v` to complete the simulation and dump the waveforms.
* **`Makefile`**: Configured to link your source files, `tb.v`, and `test.py` for both RTL and Gate-Level simulations.

## Setting up

1. Ensure the `SRC_DIR` in your [Makefile](Makefile) points to the correct location of your Verilog files.
2. Verify that `PROJECT_SOURCES` in the Makefile includes your main design file (e.g., `tt_um_hardware_anomaly_detection.v`).
3. If you change the module name in your main RTL, ensure you also update the instantiation block inside [tb.v](tb.v).

## How to run

To run the standard RTL simulation:

```sh
make -B
