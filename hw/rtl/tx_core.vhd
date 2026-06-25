library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_core is
    generic (
        SYS_CLK_HZ   : positive := 100_000_000;
        PROG_CLK_HZ  : positive := 10_000_000
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- assumed synchronized before entering tx_core
        switch_on : in std_logic;

        tx1 : out std_logic;
        tx2 : out std_logic;
        tx3 : out std_logic
    );
end entity tx_core;

architecture rtl of tx_core is

    signal mode_sel : std_logic_vector(1 downto 0);

    signal prog_start          : std_logic;
    signal prog_active         : std_logic;
    signal image_start         : std_logic;
    signal image_active        : std_logic;
    signal advance_element     : std_logic;
    signal reset_element_index : std_logic;

    signal prog_done  : std_logic;
    signal image_done : std_logic;

begin

    u_controller : entity work.tx_controller
        port map (
            clk       => clk,
            rst       => rst,
            switch_on => switch_on,

            prog_done  => prog_done,
            image_done => image_done,

            mode_sel            => mode_sel,
            prog_start          => prog_start,
            prog_active         => prog_active,
            image_start         => image_start,
            image_active        => image_active,
            advance_element     => advance_element,
            reset_element_index => reset_element_index
        );

    u_datapath : entity work.tx_datapath
        generic map (
            SYS_CLK_HZ   => SYS_CLK_HZ,
            PROG_CLK_HZ  => PROG_CLK_HZ
        )
        port map (
            clk => clk,
            rst => rst,

            mode_sel            => mode_sel,
            prog_start          => prog_start,
            prog_active         => prog_active,
            image_start         => image_start,
            image_active        => image_active,
            advance_element     => advance_element,
            reset_element_index => reset_element_index,

            prog_done  => prog_done,
            image_done => image_done,

            tx1 => tx1,
            tx2 => tx2,
            tx3 => tx3
        );

end architecture rtl;
