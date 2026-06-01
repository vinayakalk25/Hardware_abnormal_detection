# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# Assuming your Verilog source file is named project.v
# If you named it tt_um_hardware_anomaly_detection.v, update this line!
PROJECT_SOURCES = tt_um_hardware_anomaly_detection.v
ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD       = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD       = sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1

# Note: This is currently pointed at GF180. If your Tiny Tapeout project 
# is using Sky130, ensure these PDK paths are correct for your environment.
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS    += -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v

# =====================================================================
# UPDATED CONFIGURATION
# =====================================================================
# This must perfectly match the module name inside your tb.v
TOPLEVEL = tb_hardware_anomaly_detection

# cocotb expects the Python script name (without .py) to be passed in MODULE
MODULE = test

# (Keeping your original variable here just in case your TT wrapper requires it)
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup.
# THIS IS THE LINE THAT FIXES THE "NO RULE TO MAKE TARGET CLEAN" ERROR!
include $(shell cocotb-config --makefiles)/Makefile.sim
