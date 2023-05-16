LIBRARY IEEE;
USE IEEE.std_logic_1164.all;

package i2c_temp_flt_components_pkg is
  COMPONENT fix_to_float
    PORT (
      aclk : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
  END COMPONENT;
  COMPONENT flt_to_fix
    PORT (
      aclk : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;
  COMPONENT fp_addsub
    PORT (
      aclk : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_operation_tvalid : IN STD_LOGIC;
      s_axis_operation_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
  END COMPONENT;
  COMPONENT fp_fused_mult_add
    PORT (
      aclk : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_c_tvalid : IN STD_LOGIC;
      s_axis_c_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
  END COMPONENT;
  COMPONENT fp_mult
    PORT (
      aclk : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
  END COMPONENT;
end i2c_temp_flt_components_pkg;
