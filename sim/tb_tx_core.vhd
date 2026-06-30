library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_tx_core is
end entity tb_tx_core;

architecture sim of tb_tx_core is

  constant SYS_CLK_HZ   : positive := 100_000_000;
  constant PROG_CLK_HZ  : positive := 10_000_000;

  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal switch_on : std_logic := '0';

  signal tx1 : std_logic;
  signal tx2 : std_logic;
  signal tx3 : std_logic;

begin

  CLK_GEN : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process CLK_GEN;


  DUT : entity work.tx_core
    generic map (
      SYS_CLK_HZ   => SYS_CLK_HZ,
      PROG_CLK_HZ  => PROG_CLK_HZ
    )
    port map (
      clk       => clk,
      rst       => rst,
      switch_on => switch_on,

      tx1 => tx1,
      tx2 => tx2,
      tx3 => tx3
    );


  STIMULUS : process
  begin
    -- Reset.
    rst       <= '1';
    switch_on <= '0';
    wait for 100 ns;

    rst <= '0';
    wait for 100 ns;

    -- Start TX sequencing.
    switch_on <= '1';

    -- Each program/image iteration is about 20 us:
    -- 3.1 us programming + 16.9 us imaging.
    -- This shows several table entries in the waveform.
    wait for 120 us;

    -- Stop sequencing.
    switch_on <= '0';
    wait for 20 us;

    -- Start again to confirm idle reset behavior.
    switch_on <= '1';
    wait for 60 us;

    switch_on <= '0';
    wait for 10 us;

    stop;
  end process STIMULUS;

end architecture sim;
