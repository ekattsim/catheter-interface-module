----------------------------------------------------------------------------------
--
-- Name: ButtonPulser
-- Authors: Abhijeet Surakanti
--
--     This component processes the synchronized button signals and generates
--     a 20 us pulse when the button is pressed.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ButtonPulser is
	port (
		reset: in std_logic;
		clock: in std_logic;
		syncedButton: in std_logic;

		buttonPulse: out std_logic
	);
end ButtonPulser;

architecture ButtonPulser_ARCH of ButtonPulser is

	-- constants
	constant ACTIVE: std_logic := '1';
	constant PULSE_CYCLES: natural := 2000; -- 20 us at 100 MHz

	-- internal signals
	signal prevButtonValue: std_logic;
	signal pulseCount: natural range 0 to PULSE_CYCLES := 0;

begin

	PULSE_BUTTON: process(reset, clock)

	begin

		if (reset = ACTIVE) then
			buttonPulse <= not ACTIVE;
			prevButtonValue <= not ACTIVE;
			pulseCount <= 0;

		elsif (rising_edge(clock)) then
			prevButtonValue <= syncedButton;

			if (syncedButton = ACTIVE and prevButtonValue = not ACTIVE) then
				pulseCount <= PULSE_CYCLES;
				buttonPulse <= ACTIVE;

			elsif (pulseCount > 1) then
				pulseCount <= pulseCount - 1;
				buttonPulse <= ACTIVE;

			elsif (pulseCount = 1) then
				pulseCount <= 0;
				buttonPulse <= not ACTIVE;

			else
				buttonPulse <= not ACTIVE;
			end if;
		end if;

	end process;

end ButtonPulser_ARCH;
