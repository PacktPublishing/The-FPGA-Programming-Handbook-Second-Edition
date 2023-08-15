--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
--Date        : Sun Aug 13 19:06:56 2023
--Host        : DESKTOP-3TFI5BO running 64-bit major release  (build 9200)
--Command     : generate_target design_1_wrapper.bd
--Design      : design_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity design_1_wrapper is
  port (
    LED : out STD_LOGIC;
    SW : in STD_LOGIC;
    TMP_SCL : inout STD_LOGIC;
    TMP_SDA : inout STD_LOGIC;
    anode : out STD_LOGIC_VECTOR ( 7 downto 0 );
    cathode : out STD_LOGIC_VECTOR ( 7 downto 0 );
    reset : in STD_LOGIC;
    sys_clock : in STD_LOGIC
  );
end design_1_wrapper;

architecture STRUCTURE of design_1_wrapper is
  component design_1 is
  port (
    sys_clock : in STD_LOGIC;
    reset : in STD_LOGIC;
    TMP_SCL : inout STD_LOGIC;
    TMP_SDA : inout STD_LOGIC;
    anode : out STD_LOGIC_VECTOR ( 7 downto 0 );
    cathode : out STD_LOGIC_VECTOR ( 7 downto 0 );
    SW : in STD_LOGIC;
    LED : out STD_LOGIC
  );
  end component design_1;
begin
design_1_i: component design_1
     port map (
      LED => LED,
      SW => SW,
      TMP_SCL => TMP_SCL,
      TMP_SDA => TMP_SDA,
      anode(7 downto 0) => anode(7 downto 0),
      cathode(7 downto 0) => cathode(7 downto 0),
      reset => reset,
      sys_clock => sys_clock
    );
end STRUCTURE;
