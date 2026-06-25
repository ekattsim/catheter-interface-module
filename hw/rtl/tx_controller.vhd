library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_controller is
    port (
        clk : in std_logic;
        rst : in std_logic;

        switch_on : in std_logic;

        prog_done  : in std_logic;
        image_done : in std_logic;

        mode_sel : out std_logic_vector(1 downto 0);

        prog_start          : out std_logic;
        prog_active         : out std_logic;
        image_start         : out std_logic;
        image_active        : out std_logic;
        advance_element     : out std_logic;
        reset_element_index : out std_logic
    );
end entity tx_controller;

architecture rtl of tx_controller is

    constant MODE_IDLE    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_IMAGE   : std_logic_vector(1 downto 0) := "10";

    type state_t is (
    S_IDLE,
    S_PROG_START,
    S_PROG_RUN,
    S_IMAGE_START,
    S_IMAGE_RUN,
    S_ADVANCE_ELEMENT
    );

    signal state      : state_t;
    signal next_state : state_t;

begin

    STATE_REGISTER : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
            else
                state <= next_state;
            end if;
        end if;
    end process STATE_REGISTER;


    STATE_TRANSITION : process(all)
    begin
        next_state <= state;

        mode_sel            <= MODE_IDLE;
        prog_start          <= '0';
        prog_active         <= '0';
        image_start         <= '0';
        image_active        <= '0';
        advance_element     <= '0';
        reset_element_index <= '0';

        if switch_on = '0' then
            next_state <= S_IDLE;

        else
            case state is

                when S_IDLE =>
                    mode_sel            <= MODE_IDLE;
                    reset_element_index <= '1';
                    next_state          <= S_PROG_START;

                when S_PROG_START =>
                    mode_sel   <= MODE_PROGRAM;
                    prog_start <= '1';
                    next_state <= S_PROG_RUN;

                when S_PROG_RUN =>
                    mode_sel    <= MODE_PROGRAM;
                    prog_active <= '1';

                    if prog_done = '1' then
                        next_state <= S_IMAGE_START;
                    else
                        next_state <= S_PROG_RUN;
                    end if;

                when S_IMAGE_START =>
                    mode_sel    <= MODE_IMAGE;
                    image_start <= '1';
                    next_state  <= S_IMAGE_RUN;

                when S_IMAGE_RUN =>
                    mode_sel     <= MODE_IMAGE;
                    image_active <= '1';

                    if image_done = '1' then
                        next_state <= S_ADVANCE_ELEMENT;
                    else
                        next_state <= S_IMAGE_RUN;
                    end if;

                when S_ADVANCE_ELEMENT =>
                    mode_sel        <= MODE_IDLE;
                    advance_element <= '1';
                    next_state      <= S_PROG_START;

            end case;
        end if;
    end process STATE_TRANSITION;

end architecture rtl;
