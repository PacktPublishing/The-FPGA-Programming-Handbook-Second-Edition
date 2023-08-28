#*****************************************************************************************
# Vivado (TM) v2022.2 (64-bit)
#
# i2c_temp_flt_bd.tcl: Tcl script for re-creating project 'i2c_temp_flt_bd'
#
# Generated by Vivado on Fri Aug 18 10:08:28 CDT 2023
# IP Build 3669848 on Fri Oct 14 08:30:02 MDT 2022
#
# This file contains the Vivado Tcl commands for re-creating the project to the state*
# when this script was generated. In order to re-create the project, please source this
# file in the Vivado Tcl Shell.
#
# * Note that the runs in the created project will be configured the same way as the
#   original project, however they will not be launched automatically. To regenerate the
#   run results please launch the synthesis/implementation runs as needed.
#
#*****************************************************************************************
# NOTE: In order to use this script for source control purposes, please make sure that the
#       following files are added to the source control system:-
#
# 1. This project restoration tcl script (i2c_temp_flt_bd.tcl) that was generated.
#
# 2. The following source(s) files that were local or imported into the original project.
#    (Please see the '$orig_proj_dir' and '$origin_dir' variable setting below at the start of the script)
#
#    <none>
#
# 3. The following remote source files that were added to the original project:-
#
#    "/home/fbruno/git/books/The-FPGA-Programming-Handbook-Second-Edition/CH8/xdc/i2c_temp.xdc"
#
#*****************************************************************************************

# Check file required for this script exists
proc checkRequiredFiles { origin_dir} {
  set status true
  set files [list \
 "[file normalize "$origin_dir/../../../xdc/i2c_temp.xdc"]"\
  ]
  foreach ifile $files {
    if { ![file isfile $ifile] } {
      puts " Could not find remote file $ifile "
      set status false
    }
  }

  set paths [list \
 "[file normalize "$origin_dir/../../ip_repo/pdm_capture_1_0"]"]"\
 "[file normalize "$origin_dir/../../IP/pdm_capture_1_0"]"]"\
 "[file normalize "$origin_dir/../../../ip_source/flt_temp"]"]"\
 "[file normalize "$origin_dir/../../../ip_source/adt7420_i2c"]"]"\
 "[file normalize "$origin_dir/../../../ip_source/seven_segment"]"]"\
 "[file normalize "$origin_dir/../../../VHDL/IP"]"]"\
  ]
  foreach ipath $paths {
    if { ![file isdirectory $ipath] } {
      puts " Could not access $ipath "
      set status false
    }
  }

  return $status
}
# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set _xil_proj_name_ "i2c_temp_flt_bd"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

variable script_file
set script_file "i2c_temp_flt_bd.tcl"

# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Recreate a Vivado project from this script. The created project will be"
  puts "functionally equivalent to the original project for which this script was"
  puts "generated. The script contains commands for creating a project, filesets,"
  puts "runs, adding/importing sources and setting properties on various objects.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--origin_dir <path>\]"
  puts "$script_file -tclargs \[--project_name <name>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--origin_dir <path>\]  Determine source file paths wrt this path. Default"
  puts "                       origin_dir path value is \".\", otherwise, the value"
  puts "                       that was set with the \"-paths_relative_to\" switch"
  puts "                       when this script was generated.\n"
  puts "\[--project_name <name>\] Create project with the specified name. Default"
  puts "                       name is the name of the project from where this"
  puts "                       script was generated.\n"
  puts "\[--help\]               Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--origin_dir"   { incr i; set origin_dir [lindex $::argv $i] }
      "--project_name" { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"

# Check for paths and files needed for project creation
set validate_required 0
if { $validate_required } {
  if { [checkRequiredFiles $origin_dir] } {
    puts "Tcl file $script_file is valid. All files required for project creation is accesable. "
  } else {
    puts "Tcl file $script_file is not valid. Not all files required for project creation is accesable. "
    return
  }
}

# Create project
create_project ${_xil_proj_name_} ./${_xil_proj_name_} -part xc7a100tcsg324-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "board_part_repo_paths" -value "[file normalize "$origin_dir/../../../../../../../.Xilinx/Vivado/2022.2/xhub/board_store/xilinx_board_store"]" -objects $obj
set_property -name "board_part" -value "digilentinc.com:nexys-a7-100t:part0:1.2" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "platform.board_id" -value "nexys-a7-100t" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "sim_compile_state" -value "1" -objects $obj
set_property -name "webtalk.activehdl_export_sim" -value "3" -objects $obj
set_property -name "webtalk.modelsim_export_sim" -value "3" -objects $obj
set_property -name "webtalk.questa_export_sim" -value "3" -objects $obj
set_property -name "webtalk.riviera_export_sim" -value "3" -objects $obj
set_property -name "webtalk.vcs_export_sim" -value "3" -objects $obj
set_property -name "webtalk.xsim_export_sim" -value "3" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set IP repository paths
set obj [get_filesets sources_1]
if { $obj != {} } {
   set_property "ip_repo_paths" "[file normalize "$origin_dir/../ip_repo/pdm_capture_1_0"] [file normalize "$origin_dir/../IP/pdm_capture_1_0"] [file normalize "$origin_dir/../../ip_source/flt_temp"] [file normalize "$origin_dir/../../ip_source/adt7420_i2c"] [file normalize "$origin_dir/../../ip_source/seven_segment"] [file normalize "$origin_dir/../../VHDL/IP"]" $obj

   # Rebuild user ip_repo's index before adding any source files
   update_ip_catalog -rebuild
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
# Set 'sources_1' fileset file properties for remote files
# None

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "dataflow_viewer_settings" -value "min_width=16" -objects $obj
set_property -name "top" -value "design_1_wrapper" -objects $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/../../../xdc/i2c_temp.xdc"]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file "$origin_dir/../../../xdc/i2c_temp.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property -name "top" -value "design_1_wrapper" -objects $obj
set_property -name "top_lib" -value "xil_defaultlib" -objects $obj

# Set 'utils_1' fileset object
set obj [get_filesets utils_1]
# Empty (no sources present)

# Set 'utils_1' fileset properties
set obj [get_filesets utils_1]


# Adding sources referenced in BDs, if not already added


# Proc to create BD design_1
proc cr_bd_design_1 { parentCell } {

  # CHANGE DESIGN NAME HERE
  set design_name design_1

  common::send_gid_msg -ssname BD::TCL -id 2010 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  set bCheckIPsPassed 1
  ##################################################################
  # CHECK IPs
  ##################################################################
  set bCheckIPs 1
  if { $bCheckIPs == 1 } {
     set list_check_ips "\ 
  user.org:user:adt7420_i2c:1.0\
  xilinx.com:ip:clk_wiz:6.0\
  user.org:user:flt_temp:1.0\
  xilinx.com:ip:floating_point:7.1\
  user.org:user:seven_segment:1.0\
  xilinx.com:ip:util_vector_logic:2.0\
  xilinx.com:ip:xpm_cdc_gen:1.0\
  "

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

  }

  if { $bCheckIPsPassed != 1 } {
    common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
    return 3
  }

  variable script_folder

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports
  set LED [ create_bd_port -dir O LED ]
  set SW [ create_bd_port -dir I SW ]
  set TMP_CT [ create_bd_port -dir IO TMP_CT ]
  set TMP_INT [ create_bd_port -dir IO TMP_INT ]
  set TMP_SCL [ create_bd_port -dir IO TMP_SCL ]
  set TMP_SDA [ create_bd_port -dir IO TMP_SDA ]
  set anode [ create_bd_port -dir O -from 7 -to 0 anode ]
  set cathode [ create_bd_port -dir O -from 7 -to 0 cathode ]
  set reset [ create_bd_port -dir I -type rst reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $reset
  set sys_clock [ create_bd_port -dir I -type clk -freq_hz 100000000 sys_clock ]
  set_property -dict [ list \
   CONFIG.PHASE {0.0} \
 ] $sys_clock

  # Create instance: adt7420_i2c_0, and set properties
  set adt7420_i2c_0 [ create_bd_cell -type ip -vlnv user.org:user:adt7420_i2c:1.0 adt7420_i2c_0 ]

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {151.636} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
    CONFIG.RESET_BOARD_INTERFACE {reset} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $clk_wiz_0


  # Create instance: flt_temp_0, and set properties
  set flt_temp_0 [ create_bd_cell -type ip -vlnv user.org:user:flt_temp:1.0 flt_temp_0 ]

  # Create instance: fp_addsub, and set properties
  set fp_addsub [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 fp_addsub ]
  set_property -dict [list \
    CONFIG.C_Latency {11} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Has_RESULT_TREADY {false} \
  ] $fp_addsub


  # Create instance: fp_fix_to_flt, and set properties
  set fp_fix_to_flt [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 fp_fix_to_flt ]
  set_property -dict [list \
    CONFIG.A_Precision_Type {Custom} \
    CONFIG.C_A_Exponent_Width {12} \
    CONFIG.C_A_Fraction_Width {4} \
    CONFIG.C_Accum_Input_Msb {32} \
    CONFIG.C_Accum_Lsb {-31} \
    CONFIG.C_Accum_Msb {32} \
    CONFIG.C_Latency {6} \
    CONFIG.C_Mult_Usage {No_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.Result_Precision_Type {Single} \
  ] $fp_fix_to_flt


  # Create instance: fp_flt_to_fix, and set properties
  set fp_flt_to_fix [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 fp_flt_to_fix ]
  set_property -dict [list \
    CONFIG.C_Latency {6} \
    CONFIG.C_Mult_Usage {No_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.C_Result_Exponent_Width {12} \
    CONFIG.C_Result_Fraction_Width {4} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.Operation_Type {Float_to_fixed} \
    CONFIG.Result_Precision_Type {Custom} \
  ] $fp_flt_to_fix


  # Create instance: fp_fused_mult_add, and set properties
  set fp_fused_mult_add [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 fp_fused_mult_add ]
  set_property -dict [list \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.C_Latency {16} \
    CONFIG.C_Mult_Usage {Medium_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.Operation_Type {FMA} \
    CONFIG.Result_Precision_Type {Single} \
  ] $fp_fused_mult_add


  # Create instance: fp_mult, and set properties
  set fp_mult [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 fp_mult ]
  set_property -dict [list \
    CONFIG.C_Latency {8} \
    CONFIG.C_Mult_Usage {Full_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.Result_Precision_Type {Single} \
  ] $fp_mult


  # Create instance: seven_segment_0, and set properties
  set seven_segment_0 [ create_bd_cell -type ip -vlnv user.org:user:seven_segment:1.0 seven_segment_0 ]

  # Create instance: util_vector_logic_0, and set properties
  set util_vector_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0 ]
  set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
  ] $util_vector_logic_0


  # Create instance: xpm_cdc_gen_0, and set properties
  set xpm_cdc_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xpm_cdc_gen:1.0 xpm_cdc_gen_0 ]
  set_property -dict [list \
    CONFIG.CDC_TYPE {xpm_cdc_sync_rst} \
    CONFIG.INIT_SYNC_FF {false} \
  ] $xpm_cdc_gen_0


  # Create interface connections
  connect_bd_intf_net -intf_net adt7420_i2c_0_fix_temp [get_bd_intf_pins adt7420_i2c_0/fix_temp] [get_bd_intf_pins fp_fix_to_flt/S_AXIS_A]
  connect_bd_intf_net -intf_net flt_temp_0_addsub_a [get_bd_intf_pins flt_temp_0/addsub_a] [get_bd_intf_pins fp_addsub/S_AXIS_A]
  connect_bd_intf_net -intf_net flt_temp_0_addsub_b [get_bd_intf_pins flt_temp_0/addsub_b] [get_bd_intf_pins fp_addsub/S_AXIS_B]
  connect_bd_intf_net -intf_net flt_temp_0_addsub_op [get_bd_intf_pins flt_temp_0/addsub_op] [get_bd_intf_pins fp_addsub/S_AXIS_OPERATION]
  connect_bd_intf_net -intf_net flt_temp_0_fp_temp [get_bd_intf_pins flt_temp_0/fp_temp] [get_bd_intf_pins fp_flt_to_fix/S_AXIS_A]
  connect_bd_intf_net -intf_net flt_temp_0_fused_a [get_bd_intf_pins flt_temp_0/fused_a] [get_bd_intf_pins fp_fused_mult_add/S_AXIS_A]
  connect_bd_intf_net -intf_net flt_temp_0_fused_b [get_bd_intf_pins flt_temp_0/fused_b] [get_bd_intf_pins fp_fused_mult_add/S_AXIS_B]
  connect_bd_intf_net -intf_net flt_temp_0_fused_c [get_bd_intf_pins flt_temp_0/fused_c] [get_bd_intf_pins fp_fused_mult_add/S_AXIS_C]
  connect_bd_intf_net -intf_net flt_temp_0_mult_a [get_bd_intf_pins flt_temp_0/mult_a] [get_bd_intf_pins fp_mult/S_AXIS_A]
  connect_bd_intf_net -intf_net flt_temp_0_mult_b [get_bd_intf_pins flt_temp_0/mult_b] [get_bd_intf_pins fp_mult/S_AXIS_B]
  connect_bd_intf_net -intf_net flt_temp_0_seven_segment [get_bd_intf_pins flt_temp_0/seven_segment] [get_bd_intf_pins seven_segment_0/seven_segment]
  connect_bd_intf_net -intf_net fp_addsub_M_AXIS_RESULT [get_bd_intf_pins flt_temp_0/addsub] [get_bd_intf_pins fp_addsub/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net fp_fix_to_flt_M_AXIS_RESULT [get_bd_intf_pins flt_temp_0/fix_temp] [get_bd_intf_pins fp_fix_to_flt/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net fp_flt_to_fix_M_AXIS_RESULT [get_bd_intf_pins flt_temp_0/fx_temp] [get_bd_intf_pins fp_flt_to_fix/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net fp_fused_mult_add_M_AXIS_RESULT [get_bd_intf_pins flt_temp_0/fused] [get_bd_intf_pins fp_fused_mult_add/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net fp_mult_M_AXIS_RESULT [get_bd_intf_pins flt_temp_0/mult] [get_bd_intf_pins fp_mult/M_AXIS_RESULT]

  # Create port connections
  connect_bd_net -net Net [get_bd_ports TMP_SCL] [get_bd_pins adt7420_i2c_0/TMP_SCL]
  connect_bd_net -net Net1 [get_bd_ports TMP_SDA] [get_bd_pins adt7420_i2c_0/TMP_SDA]
  connect_bd_net -net Net2 [get_bd_ports TMP_INT] [get_bd_pins adt7420_i2c_0/TMP_INT]
  connect_bd_net -net Net3 [get_bd_ports TMP_CT] [get_bd_pins adt7420_i2c_0/TMP_CT]
  connect_bd_net -net SW_0_1 [get_bd_ports SW] [get_bd_pins flt_temp_0/SW]
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins adt7420_i2c_0/clk] [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins flt_temp_0/clk] [get_bd_pins fp_addsub/aclk] [get_bd_pins fp_fix_to_flt/aclk] [get_bd_pins fp_flt_to_fix/aclk] [get_bd_pins fp_fused_mult_add/aclk] [get_bd_pins fp_mult/aclk] [get_bd_pins seven_segment_0/clk] [get_bd_pins xpm_cdc_gen_0/dest_clk]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins xpm_cdc_gen_0/src_rst]
  connect_bd_net -net flt_temp_0_LED [get_bd_ports LED] [get_bd_pins flt_temp_0/LED]
  connect_bd_net -net reset_1 [get_bd_ports reset] [get_bd_pins clk_wiz_0/resetn]
  connect_bd_net -net seven_segment_0_anode [get_bd_ports anode] [get_bd_pins seven_segment_0/anode]
  connect_bd_net -net seven_segment_0_cathode [get_bd_ports cathode] [get_bd_pins seven_segment_0/cathode]
  connect_bd_net -net sys_clock_1 [get_bd_ports sys_clock] [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins adt7420_i2c_0/rst] [get_bd_pins flt_temp_0/rst] [get_bd_pins seven_segment_0/rst] [get_bd_pins util_vector_logic_0/Res]
  connect_bd_net -net xpm_cdc_gen_0_dest_rst_out [get_bd_pins fp_addsub/aresetn] [get_bd_pins fp_fix_to_flt/aresetn] [get_bd_pins fp_flt_to_fix/aresetn] [get_bd_pins fp_fused_mult_add/aresetn] [get_bd_pins fp_mult/aresetn] [get_bd_pins util_vector_logic_0/Op1] [get_bd_pins xpm_cdc_gen_0/dest_rst_out]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
  close_bd_design $design_name 
}
# End of cr_bd_design_1()
cr_bd_design_1 ""
set_property GENERATE_SYNTH_CHECKPOINT "0" [get_files design_1.bd ] 
set_property REGISTERED_WITH_MANAGER "1" [get_files design_1.bd ] 

#call make_wrapper to create wrapper files
if { [get_property IS_LOCKED [ get_files -norecurse design_1.bd] ] == 1  } {
  import_files -fileset sources_1 [file normalize "${origin_dir}/i2c_temp_flt_bd.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v" ]
} else {
  set wrapper_path [make_wrapper -fileset sources_1 -files [ get_files -norecurse design_1.bd] -top]
  add_files -norecurse -fileset sources_1 $wrapper_path
}


set idrFlowPropertiesConstraints ""
catch {
 set idrFlowPropertiesConstraints [get_param runs.disableIDRFlowPropertyConstraints]
 set_param runs.disableIDRFlowPropertyConstraints 1
}

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part xc7a100tcsg324-1 -flow {Vivado Synthesis 2022} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2022" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property set_report_strategy_name 1 $obj
set_property report_strategy {Vivado Synthesis Default Reports} $obj
set_property set_report_strategy_name 0 $obj
# Create 'synth_1_synth_report_utilization_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0] "" ] } {
  create_report_config -report_name synth_1_synth_report_utilization_0 -report_type report_utilization:1.0 -steps synth_design -runs synth_1
}
set obj [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0]
if { $obj != "" } {

}
set obj [get_runs synth_1]
set_property -name "needs_refresh" -value "1" -objects $obj
set_property -name "incremental_checkpoint" -value "$proj_dir/i2c_temp_flt_bd.srcs/utils_1/imports/synth_1/design_1_wrapper.dcp" -objects $obj
set_property -name "auto_incremental_checkpoint" -value "1" -objects $obj
set_property -name "strategy" -value "Vivado Synthesis Defaults" -objects $obj
set_property -name "steps.synth_design.args.incremental_mode" -value "off" -objects $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part xc7a100tcsg324-1 -flow {Vivado Implementation 2022} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2022" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property set_report_strategy_name 1 $obj
set_property report_strategy {Vivado Implementation Default Reports} $obj
set_property set_report_strategy_name 0 $obj
# Create 'impl_1_init_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_init_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_init_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps init_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_init_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_opt_report_drc_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_opt_report_drc_0] "" ] } {
  create_report_config -report_name impl_1_opt_report_drc_0 -report_type report_drc:1.0 -steps opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_opt_report_drc_0]
if { $obj != "" } {

}
# Create 'impl_1_opt_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_opt_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_opt_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_power_opt_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_power_opt_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_power_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps power_opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_power_opt_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_place_report_io_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_io_0] "" ] } {
  create_report_config -report_name impl_1_place_report_io_0 -report_type report_io:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_io_0]
if { $obj != "" } {

}
# Create 'impl_1_place_report_utilization_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_utilization_0] "" ] } {
  create_report_config -report_name impl_1_place_report_utilization_0 -report_type report_utilization:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_utilization_0]
if { $obj != "" } {

}
# Create 'impl_1_place_report_control_sets_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_control_sets_0] "" ] } {
  create_report_config -report_name impl_1_place_report_control_sets_0 -report_type report_control_sets:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_control_sets_0]
if { $obj != "" } {
set_property -name "options.verbose" -value "1" -objects $obj

}
# Create 'impl_1_place_report_incremental_reuse_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_incremental_reuse_0] "" ] } {
  create_report_config -report_name impl_1_place_report_incremental_reuse_0 -report_type report_incremental_reuse:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_incremental_reuse_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj

}
# Create 'impl_1_place_report_incremental_reuse_1' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_incremental_reuse_1] "" ] } {
  create_report_config -report_name impl_1_place_report_incremental_reuse_1 -report_type report_incremental_reuse:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_incremental_reuse_1]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj

}
# Create 'impl_1_place_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_place_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps place_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_post_place_power_opt_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_place_power_opt_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_post_place_power_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps post_place_power_opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_place_power_opt_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_phys_opt_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_phys_opt_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_phys_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps phys_opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_phys_opt_report_timing_summary_0]
if { $obj != "" } {
set_property -name "is_enabled" -value "0" -objects $obj
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_route_report_drc_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_drc_0] "" ] } {
  create_report_config -report_name impl_1_route_report_drc_0 -report_type report_drc:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_drc_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_methodology_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_methodology_0] "" ] } {
  create_report_config -report_name impl_1_route_report_methodology_0 -report_type report_methodology:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_methodology_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_power_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_power_0] "" ] } {
  create_report_config -report_name impl_1_route_report_power_0 -report_type report_power:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_power_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_route_status_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_route_status_0] "" ] } {
  create_report_config -report_name impl_1_route_report_route_status_0 -report_type report_route_status:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_route_status_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_route_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_timing_summary_0]
if { $obj != "" } {
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj

}
# Create 'impl_1_route_report_incremental_reuse_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_incremental_reuse_0] "" ] } {
  create_report_config -report_name impl_1_route_report_incremental_reuse_0 -report_type report_incremental_reuse:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_incremental_reuse_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_clock_utilization_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_clock_utilization_0] "" ] } {
  create_report_config -report_name impl_1_route_report_clock_utilization_0 -report_type report_clock_utilization:1.0 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_clock_utilization_0]
if { $obj != "" } {

}
# Create 'impl_1_route_report_bus_skew_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_bus_skew_0] "" ] } {
  create_report_config -report_name impl_1_route_report_bus_skew_0 -report_type report_bus_skew:1.1 -steps route_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_bus_skew_0]
if { $obj != "" } {
set_property -name "options.warn_on_violation" -value "1" -objects $obj

}
# Create 'impl_1_post_route_phys_opt_report_timing_summary_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0] "" ] } {
  create_report_config -report_name impl_1_post_route_phys_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps post_route_phys_opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0]
if { $obj != "" } {
set_property -name "options.max_paths" -value "10" -objects $obj
set_property -name "options.report_unconstrained" -value "1" -objects $obj
set_property -name "options.warn_on_violation" -value "1" -objects $obj

}
# Create 'impl_1_post_route_phys_opt_report_bus_skew_0' report (if not found)
if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_bus_skew_0] "" ] } {
  create_report_config -report_name impl_1_post_route_phys_opt_report_bus_skew_0 -report_type report_bus_skew:1.1 -steps post_route_phys_opt_design -runs impl_1
}
set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_bus_skew_0]
if { $obj != "" } {
set_property -name "options.warn_on_violation" -value "1" -objects $obj

}
set obj [get_runs impl_1]
set_property -name "needs_refresh" -value "1" -objects $obj
set_property -name "strategy" -value "Vivado Implementation Defaults" -objects $obj
set_property -name "steps.write_bitstream.args.readback_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.verbose" -value "0" -objects $obj

# set the current impl run
current_run -implementation [get_runs impl_1]
catch {
 if { $idrFlowPropertiesConstraints != {} } {
   set_param runs.disableIDRFlowPropertyConstraints $idrFlowPropertiesConstraints
 }
}

puts "INFO: Project created:${_xil_proj_name_}"
# Create 'drc_1' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "drc_1" ] ] ""]} {
create_dashboard_gadget -name {drc_1} -type drc
}
set obj [get_dashboard_gadgets [ list "drc_1" ] ]
set_property -name "reports" -value "impl_1#impl_1_route_report_drc_0" -objects $obj

# Create 'methodology_1' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "methodology_1" ] ] ""]} {
create_dashboard_gadget -name {methodology_1} -type methodology
}
set obj [get_dashboard_gadgets [ list "methodology_1" ] ]
set_property -name "reports" -value "impl_1#impl_1_route_report_methodology_0" -objects $obj

# Create 'power_1' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "power_1" ] ] ""]} {
create_dashboard_gadget -name {power_1} -type power
}
set obj [get_dashboard_gadgets [ list "power_1" ] ]
set_property -name "reports" -value "impl_1#impl_1_route_report_power_0" -objects $obj

# Create 'timing_1' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "timing_1" ] ] ""]} {
create_dashboard_gadget -name {timing_1} -type timing
}
set obj [get_dashboard_gadgets [ list "timing_1" ] ]
set_property -name "reports" -value "impl_1#impl_1_route_report_timing_summary_0" -objects $obj

# Create 'utilization_1' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "utilization_1" ] ] ""]} {
create_dashboard_gadget -name {utilization_1} -type utilization
}
set obj [get_dashboard_gadgets [ list "utilization_1" ] ]
set_property -name "reports" -value "synth_1#synth_1_synth_report_utilization_0" -objects $obj
set_property -name "run.step" -value "synth_design" -objects $obj
set_property -name "run.type" -value "synthesis" -objects $obj

# Create 'utilization_2' gadget (if not found)
if {[string equal [get_dashboard_gadgets  [ list "utilization_2" ] ] ""]} {
create_dashboard_gadget -name {utilization_2} -type utilization
}
set obj [get_dashboard_gadgets [ list "utilization_2" ] ]
set_property -name "reports" -value "impl_1#impl_1_place_report_utilization_0" -objects $obj

move_dashboard_gadget -name {utilization_1} -row 0 -col 0
move_dashboard_gadget -name {power_1} -row 1 -col 0
move_dashboard_gadget -name {drc_1} -row 2 -col 0
move_dashboard_gadget -name {timing_1} -row 0 -col 1
move_dashboard_gadget -name {utilization_2} -row 1 -col 1
move_dashboard_gadget -name {methodology_1} -row 2 -col 1
