library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tx_datapath is
    generic (
        SYS_CLK_HZ  : positive := 100_000_000;
        PROG_CLK_HZ : positive := 10_000_000
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        mode_sel : in std_logic_vector(1 downto 0);

        prog_start          : in std_logic;
        prog_active         : in std_logic;
        image_start         : in std_logic;
        image_active        : in std_logic;
        advance_element     : in std_logic;
        reset_element_index : in std_logic;

        prog_done  : out std_logic;
        image_done : out std_logic;

        tx1 : out std_logic;
        tx2 : out std_logic;
        tx3 : out std_logic
    );
end entity tx_datapath;

architecture rtl of tx_datapath is

    constant MODE_IDLE    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_IMAGE   : std_logic_vector(1 downto 0) := "10";

    constant WORD_WIDTH : positive := 31;

    constant PROG_HALF_PERIOD_CYCLES : positive :=
                                                SYS_CLK_HZ / (2 * PROG_CLK_HZ);

    -- 16.9 us = 1690 cycles @ 100 MHz
	constant IMAGE_CYCLES : positive := integer(ceil(16.9e-6 * real(SYS_CLK_HZ)));

    constant IMAGE_PULSE_OFFSET_CYCLES : natural := IMAGE_CYCLES / 2;
    -- constant IMAGE_PULSE_OFFSET_CYCLES : natural := 20;
    constant IMAGE_PULSE_WIDTH_CYCLES  : natural := 50;

    subtype word_t is std_logic_vector(WORD_WIDTH - 1 downto 0);

    constant NUM_CHIPS         : positive := 8;
    constant ELEMENTS_PER_CHIP : positive := 12;
    constant NUM_FIRINGS       : positive := NUM_CHIPS * ELEMENTS_PER_CHIP * ELEMENTS_PER_CHIP;

    type element_array_t is array (0 to NUM_FIRINGS - 1) of word_t;

    function make_element_word (
        chip    : natural;
        tx_elem : natural;
        rx_elem : natural
    ) return word_t is
        variable word_v    : word_t                        := (others => '0');
        variable tx_mask_v : std_logic_vector(11 downto 0) := (others => '0');
    begin
        tx_mask_v(tx_elem) := '1';

        -- Serial protocol, MSB-first:
        --
        -- [30:25]  6-bit latch       = "111111"
        -- [24:22]  3-bit TX CS       = chip
        -- [21]     separator         = '0'
        -- [20:18]  3-bit RX CS       = chip
        -- [17]     separator         = '0'
        -- [16:5]   12-bit active TX  = one-hot tx_elem
        -- [4]      separator         = '0'
        -- [3:0]    4-bit active RX   = rx_elem

        word_v(30 downto 25) := "111111";
        word_v(24 downto 22) := std_logic_vector(to_unsigned(chip, 3));
        word_v(21)           := '0';
        word_v(20 downto 18) := std_logic_vector(to_unsigned(chip, 3));
        word_v(17)           := '0';
        word_v(16 downto 5)  := tx_mask_v;
        word_v(4)            := '0';
        word_v(3 downto 0)   := std_logic_vector(to_unsigned(rx_elem, 4));

        return word_v;
    end function make_element_word;


    function generate_element_array
        return element_array_t is
        variable array_v : element_array_t := (others => (others => '0'));
        variable idx_v   : natural         := 0;
    begin
        for chip in 0 to NUM_CHIPS - 1 loop
            for tx_elem in 0 to ELEMENTS_PER_CHIP - 1 loop
                for rx_elem in 0 to ELEMENTS_PER_CHIP - 1 loop
                    array_v(idx_v) := make_element_word(
                        chip    => chip,
                        tx_elem => tx_elem,
                        rx_elem => rx_elem
                    );

                    idx_v := idx_v + 1;
                end loop;
            end loop;
        end loop;

        return array_v;
    end function generate_element_array;

    constant ELEMENT_ARRAY : element_array_t := generate_element_array;

    signal element_index : natural range 0 to NUM_FIRINGS - 1;
    signal current_word  : word_t;

    signal prog_tx1    : std_logic;
    signal prog_tx2    : std_logic;
    signal prog_tx3    : std_logic;
    signal prog_done_i : std_logic;

    signal image_tx1    : std_logic;
    signal image_tx2    : std_logic;
    signal image_tx3    : std_logic;
    signal image_done_i : std_logic;

    signal tx1_next : std_logic;
    signal tx2_next : std_logic;
    signal tx3_next : std_logic;

begin

    assert SYS_CLK_HZ mod (2 * PROG_CLK_HZ) = 0
        report "SYS_CLK_HZ must be an integer multiple of 2*PROG_CLK_HZ"
        severity failure;

    assert SYS_CLK_HZ mod 10_000_000 = 0
        report "SYS_CLK_HZ must be divisible by 10 MHz to represent 16.9 us exactly"
        severity failure;

    assert IMAGE_PULSE_OFFSET_CYCLES + IMAGE_PULSE_WIDTH_CYCLES <= IMAGE_CYCLES
        report "Image pulse window must fit inside the 16.9 us image window"
        severity failure;


    current_word <= ELEMENT_ARRAY(element_index);

    prog_done  <= prog_done_i;
    image_done <= image_done_i;


    ELEMENT_INDEX_REGISTER : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                element_index <= 0;

            elsif reset_element_index = '1' then
                element_index <= 0;

            elsif advance_element = '1' then
                if element_index = NUM_FIRINGS - 1 then
                    element_index <= 0;
                else
                    element_index <= element_index + 1;
                end if;
            end if;
        end if;
    end process ELEMENT_INDEX_REGISTER;


    PROGRAM_TX_GEN : process(clk)
        variable shift_reg      : word_t                                         := (others => '0');
        variable bit_count      : natural range 0 to WORD_WIDTH                  := 0;
        variable prog_clk_count : natural range 0 to PROG_HALF_PERIOD_CYCLES - 1 := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                shift_reg      := (others => '0');
                bit_count      := 0;
                prog_clk_count := 0;

                prog_tx1    <= '0';
                prog_tx2    <= '0';
                prog_tx3    <= '0';
                prog_done_i <= '0';

            else
                prog_done_i <= '0';

                if prog_start = '1' then
                    shift_reg      := current_word;
                    bit_count      := 0;
                    prog_clk_count := 0;

                    prog_tx1 <= '1';
                    prog_tx2 <= current_word(WORD_WIDTH - 1);  -- MSB first
                    prog_tx3 <= '0';

                elsif prog_active = '1' then
                    prog_tx1 <= '1';

                    if bit_count < WORD_WIDTH then
                        if prog_clk_count = PROG_HALF_PERIOD_CYCLES - 1 then
                            prog_clk_count := 0;

                            if prog_tx3 = '0' then
                                -- Rising edge of generated tx3.
                                -- tx2 has already been stable during the preceding low phase.
                                prog_tx3 <= '1';

                            else
                                -- Falling edge of generated tx3.
                                -- Advance to the next serial bit after this edge.
                                prog_tx3 <= '0';

                                if bit_count = WORD_WIDTH - 1 then
                                    bit_count   := WORD_WIDTH;
                                    prog_tx2    <= '0';
                                    prog_done_i <= '1';

                                else
                                    bit_count := bit_count + 1;
                                    shift_reg := shift_reg(WORD_WIDTH - 2 downto 0) & '0';
                                    prog_tx2  <= shift_reg(WORD_WIDTH - 1);
                                end if;
                            end if;

                        else
                            prog_clk_count := prog_clk_count + 1;
                        end if;

                    else
                        prog_clk_count := 0;
                        prog_tx2       <= '0';
                        prog_tx3       <= '0';
                    end if;

                else
                    shift_reg      := (others => '0');
                    bit_count      := 0;
                    prog_clk_count := 0;

                    prog_tx1 <= '0';
                    prog_tx2 <= '0';
                    prog_tx3 <= '0';
                end if;
            end if;
        end if;
    end process PROGRAM_TX_GEN;


    IMAGE_TX_GEN : process(clk)
        variable image_count : natural range 0 to IMAGE_CYCLES := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                image_count := 0;

                image_tx1    <= '0';
                image_tx2    <= '0';
                image_tx3    <= '0';
                image_done_i <= '0';

            else
                image_done_i <= '0';

                if image_start = '1' then
                    image_count := 0;

                    image_tx1 <= '0';
                    image_tx2 <= '0';
                    image_tx3 <= '0';

                elsif image_active = '1' then
                    if image_count >= IMAGE_PULSE_OFFSET_CYCLES and
                       image_count < IMAGE_PULSE_OFFSET_CYCLES + IMAGE_PULSE_WIDTH_CYCLES then
                        image_tx1 <= '1';
                        image_tx2 <= '1';
                        image_tx3 <= '1';
                    else
                        image_tx1 <= '0';
                        image_tx2 <= '0';
                        image_tx3 <= '0';
                    end if;

                    if image_count >= IMAGE_CYCLES - 1 then
                        image_count  := IMAGE_CYCLES;
                        image_done_i <= '1';
                    else
                        image_count := image_count + 1;
                    end if;

                else
                    image_count := 0;

                    image_tx1 <= '0';
                    image_tx2 <= '0';
                    image_tx3 <= '0';
                end if;
            end if;
        end if;
    end process IMAGE_TX_GEN;


    TX_OUTPUT_MUX : process(all)
    begin
        tx1_next <= '0';
        tx2_next <= '0';
        tx3_next <= '0';

        case mode_sel is

            when MODE_PROGRAM =>
                tx1_next <= prog_tx1;
                tx2_next <= prog_tx2;
                tx3_next <= prog_tx3;

            when MODE_IMAGE =>
                tx1_next <= image_tx1;
                tx2_next <= image_tx2;
                tx3_next <= image_tx3;

            when MODE_IDLE =>
                tx1_next <= '0';
                tx2_next <= '0';
                tx3_next <= '0';

            when others =>
                tx1_next <= '0';
                tx2_next <= '0';
                tx3_next <= '0';

        end case;
    end process TX_OUTPUT_MUX;


    TX_OUTPUT_REGISTER : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx1 <= '0';
                tx2 <= '0';
                tx3 <= '0';
            else
                tx1 <= tx1_next;
                tx2 <= tx2_next;
                tx3 <= tx3_next;
            end if;
        end if;
    end process TX_OUTPUT_REGISTER;

end architecture rtl;
