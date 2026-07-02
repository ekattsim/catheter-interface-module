library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------
--
-- Name: ButtonDebouncer
-- Designers: Abhijeet Surakanti
--
-- 		This component takes an asynchronous button signal
-- 		and translates it into a clean debounced and synced
-- 		signal.
--
-- 		It does this by checking whether the input signal
-- 		has stabilized into either a HIGH or LOW.
--------------------------------------------------------------

entity ButtonDebouncer is
	generic (STABLE_PERIOD : positive);
	port (
		reset : in std_logic;
		clock : in std_logic;
		asyncButton : in std_logic;
		cleanButton : out std_logic
	);
end ButtonDebouncer;

architecture ButtonDebouncer_ARCH of ButtonDebouncer is

	constant ACTIVE : std_logic := '1';
	constant STABLE_LOW : std_logic_vector(STABLE_PERIOD-1 downto 0) := (others => '0');
	constant STABLE_HIGH : std_logic_vector(STABLE_PERIOD-1 downto 0) := (others => '1');
	signal prevStatesReg : std_logic_vector(STABLE_PERIOD-1 downto 0);
	
	signal meta : std_logic := '0';
	signal sync : std_logic := '0';

begin

	CHECK_STABILITY: process (reset, clock)

	begin

		if (reset=ACTIVE) then
			prevStatesReg <= (others => '0');
			meta <= '0';
			sync <= '0';
			cleanButton <= '0';
		elsif (rising_edge(clock)) then
			meta <= asyncButton;
			sync <= meta;
			prevStatesReg <= sync & prevStatesReg(STABLE_PERIOD-1 downto 1);

			if (prevStatesReg=STABLE_LOW) then
				cleanButton <= '0';
			elsif (prevStatesReg=STABLE_HIGH) then
				cleanButton <= '1';
			end if;
		end if;

	end process;

end ButtonDebouncer_ARCH;
