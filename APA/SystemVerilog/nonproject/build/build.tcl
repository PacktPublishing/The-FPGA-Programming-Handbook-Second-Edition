source ../scripts/vivado_procedures.tcl
set PLACE_DIRECTIVE "WLDrivenBlockPlacement"
set ROUTE_DIRECTIVE "NoTimingRelaxation"
set POST_PLACE_PHYS_OPT_LOOPS 1
set POST_ROUTE_PHYS_OPT_LOOPS 1
set IGNORE_TNS 0
set TOP_MODULE final_project

# DCP files are read-in via sourcing of the following file
set ip_dcps "ip_dcps.tcl"

# Debug: Add ILA (Set to 1 if you need to do a debug build - if $ifa_file is missing, vivado GUI will come up after synthesis with further instructions on its TCL console)
set ila_insert 0
set ila_file   "ila_insert.tcl"

# Let's keep track of time
set CUR_TIME [clock seconds]

# Process Management
set TERM_FILE ".stop"

# Let's keep track design timing and checkpoint files throughout the build
set timing_result    {}
set WNS              -100
set TNS              -10000
set WNS_PREV         $WNS
set TNS_PREV         $TNS
set BEST_CP          ""
set CHECKPOINT_SAVED 0

# Create
set hdl_files [glob ../../../../CH10/IP/ddr2_vga/ddr2_vga.xci \
                   ../../../../CH10/IP/pix_clk/pix_clk.xci \
                   ../../../../CH10/IP/sys_pll/sys_pll.xci \
                   ../../../../CH7/IP/fix_to_float/fix_to_float.xci \
                   ../../../../CH7/IP/flt_to_fix/flt_to_fix.xci \
                   ../../../../CH7/IP/fp_addsub/fp_addsub.xci \
                   ../../../../CH7/IP/fp_fused_mult_add/fp_fused_mult_add.xci \
                   ../../../../CH7/IP/fp_mult/fp_mult.xci \
                   ../../../../CH7/SystemVerilog/hdl/temp_pkg.sv \
                   ../../../../CH11/SystemVerilog/hdl/*.sv]

read_files $hdl_files

synthesis

pre_implement

implement
