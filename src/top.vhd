library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity basys_top is
    port (
        clk : in std_logic;

        sw   : in std_logic_vector(15 downto 0);
        btnC : in std_logic;
		btnR : in std_logic;

        JA : out std_logic_vector(7 downto 0);
        led : out std_logic_vector(15 downto 0)
    );
end entity basys_top;

architecture rtl of basys_top is

    signal sw_meta : std_logic := '0';
    signal sw_sync : std_logic := '0';
	
	signal reset : std_logic;
	
	signal nextFiring : std_logic;

    signal tx1_i : std_logic;
    signal tx2_i : std_logic;
    signal tx3_i : std_logic;

begin

    led(0) <= '1';
    led(15 downto 1) <= (others => '0');
	
	RESET_DEBOUNCER: entity work.ButtonDebouncer
		generic map (
			STABLE_PERIOD => 10
		)
		port map (
			reset => '0',
			clock => clk,
			asyncButton => btnC,
			cleanButton => reset
		);
	
	NEXT_FIRING_DEBOUNCER: entity work.ButtonDebouncer
		generic map (
			STABLE_PERIOD => 10
		)
		port map (
			reset => reset,
			clock => clk,
			asyncButton => btnR,
			cleanButton => nextFiring
		);

    -- Simple 2-FF synchronizers.
    -- sw(0) is used as active-high run switch.
    SYNC_INPUTS : process(clk)
    begin
        if rising_edge(clk) then
            sw_meta <= sw(0);
            sw_sync <= sw_meta;
        end if;
    end process SYNC_INPUTS;


    u_tx_core : entity work.tx_core
        generic map (
            SYS_CLK_HZ  => 100_000_000,
            PROG_CLK_HZ => 10_000_000
        )
        port map (
            clk       => clk,
            rst       => reset,
            switch_on => sw_sync,
			next_firing => nextFiring,

            tx1 => tx1_i,
            tx2 => tx2_i,
            tx3 => tx3_i
        );


    -- PMOD JA:
    -- ja(0) = JA pin 1
    -- ja(1) = JA pin 2
    -- ja(2) = JA pin 3
    JA(0) <= tx1_i;
    JA(1) <= tx2_i;
    JA(2) <= tx3_i;

    JA(7 downto 3) <= (others => '0');

end architecture rtl;
