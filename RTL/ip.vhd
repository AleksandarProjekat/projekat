----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/16/2024 14:10:51 PM
-- Design Name:
-- Module Name: ip - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity ip is
    generic (
        WIDTH : integer := 11;            -- Bit width for various unsigned signals
        PIXEL_SIZE : integer := 14;       -- 128 x 128 pixels
        FIXED_SIZE : integer := 48;       -- Bit width for fixed-point operations
        INDEX_SIZE : integer := 4;        -- Dimension size for the index array
        IMG_WIDTH : integer := 128;       -- Width of the image
        IMG_HEIGHT : integer := 128       -- Height of the image
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        iradius : in unsigned(WIDTH - 1 downto 0);
        fracr : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        fracc : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        spacing : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        iy : in unsigned(WIDTH - 1 downto 0);
        ix : in unsigned(WIDTH - 1 downto 0);
        step : in unsigned(WIDTH - 1 downto 0);
        i_cose : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        i_sine : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        scale : in std_logic_vector(FIXED_SIZE - 1 downto 0);
        ---------------MEM INTERFEJS ZA SLIKU--------------------
        bram_addr1_o : out std_logic_vector(PIXEL_SIZE-1 downto 0);
        bram_addr2_o : out std_logic_vector(PIXEL_SIZE-1 downto 0);
        bram_data1_i : in std_logic_vector(7 downto 0);
        bram_data2_i : in std_logic_vector(7 downto 0);
        bram_en1_o : out std_logic;
        bram_we1_o : out std_logic;
        bram_en2_o : out std_logic;
        bram_we2_o : out std_logic;
        ---------------MEM INTERFEJS ZA IZLAZ--------------------
        addr_do1_o : out std_logic_vector (5 downto 0);
        data1_o_next : out std_logic_vector (2* FIXED_SIZE - 1 downto 0);
        c1_data_o : out std_logic;
        addr_do2_o : out std_logic_vector (5 downto 0);
        data2_o_next : out std_logic_vector (2*FIXED_SIZE - 1 downto 0);
        c2_data_o : out std_logic;
        ---------------INTERFEJS ZA ROM--------------------
        rom_addr : out std_logic_vector(5 downto 0);  
        rom_data : in std_logic_vector(FIXED_SIZE - 1 downto 0);  
        ---------------KOMANDNI INTERFEJS------------------------
        start_i : in std_logic;
        ---------------STATUSNI INTERFEJS------------------------
        ready_o : out std_logic
    );
end ip;

architecture Behavioral of ip is
    -- Definisanje internog signala za kombinatornu logiku
    signal data1_o_next_int, data2_o_next_int : std_logic_vector (2*FIXED_SIZE - 1 downto 0);  -- Interne signale za kombinatornu logiku

    type state_type is (idle, StartLoop, InnerLoop, BoundaryCheck, PositionValidation, ProcessSample,
        ComputeDerivatives, FetchDXX1_1, FetchDXX1_2, FetchDXX1_3, FetchDXX1_4, ComputeDXX1,
                        FetchDXX2_1, FetchDXX2_2, FetchDXX2_3, FetchDXX2_4, ComputeDXX2,
                        FetchDYY1_1, FetchDYY1_2, FetchDYY1_3, FetchDYY1_4, ComputeDYY1,
                        FetchDYY2_1, FetchDYY2_2, FetchDYY2_3, FetchDYY2_4, ComputeDYY2, CalculateDerivatives, ApplyOrientationTransform,
        SetOrientations, UpdateIndex, ComputeWeights, UpdateIndexArray, CheckNextColumn, CheckNextRow,
        NextSample, IncrementI, Finish);

    -- za SIGNALE VIDETI KOJI JE TIP I SIRINA
    signal state_reg, state_next : state_type;

    signal bram_data1, bram_data2 : std_logic_vector(7 downto 0);
    signal dxx1_sum_next, dxx2_sum_next, dyy1_sum_next, dyy2_sum_next : std_logic_vector(FIXED_SIZE-1 downto 0); -- Accumulators for sum of BRAM data
    signal dxx1_sum_reg, dxx2_sum_reg, dyy1_sum_reg, dyy2_sum_reg : std_logic_vector(FIXED_SIZE-1 downto 0);

    signal data1_o_reg, data2_o_reg : std_logic_vector (2*FIXED_SIZE - 1 downto 0);  -- KOLIKA SIRINA

    signal i_reg, i_next : unsigned(WIDTH - 1 downto 0) := to_unsigned(23, WIDTH); -- STA OVDE IDE
    signal j_reg, j_next : unsigned(WIDTH - 1 downto 0) := to_unsigned(23, WIDTH);
    signal ri, ci : unsigned(WIDTH - 1 downto 0);
    signal ri_next, ci_next : unsigned(WIDTH - 1 downto 0);
    signal r, c : signed(WIDTH - 1 downto 0);
    signal r_next, c_next : signed(WIDTH - 1 downto 0);
    signal addSampleStep, addSampleStep_next : unsigned(WIDTH - 1 downto 0);
    signal rpos, cpos : std_logic_vector(FIXED_SIZE-1 downto 0);
    signal rpos_next, cpos_next : std_logic_vector(FIXED_SIZE-1 downto 0); -- AKO SE MNOZE DVA BROJA ONDA CE ZA REZULTAT ICI 2*FIXED_SIZE
    signal rx, cx, rfrac, cfrac, dx, dy, dxx, dyy, weight :  std_logic_vector(FIXED_SIZE-1 downto 0);
    signal rx_next, cx_next, rfrac_next, cfrac_next, dx_next, dy_next, dxx_next, dyy_next, weight_next : std_logic_vector(FIXED_SIZE-1 downto 0);
    signal rweight1, rweight2, cweight1, cweight2 : std_logic_vector(FIXED_SIZE-1 downto 0);
    signal rweight1_next, rweight2_next, cweight1_next, cweight2_next : std_logic_vector(FIXED_SIZE-1 downto 0);
    signal ori1, ori2 : unsigned(WIDTH - 1 downto 0);
    signal ori1_next, ori2_next : unsigned(WIDTH - 1 downto 0);

    signal dxx1, dxx2, dyy1, dyy2 : std_logic_vector(FIXED_SIZE-1 downto 0);
    signal dxx1_next, dxx2_next, dyy1_next, dyy2_next : std_logic_vector(FIXED_SIZE-1 downto 0);

    signal done : std_logic;

    -- Definisanje internog signala za adrese
    signal bram_addr1_int, bram_addr2_int : std_logic_vector(PIXEL_SIZE-1 downto 0);
    signal bram_addr1_next, bram_addr2_next : std_logic_vector(PIXEL_SIZE-1 downto 0);

    -- Signal za rom_addr
    signal rom_addr_next : std_logic_vector(5 downto 0);

begin
    -- Sekvencijalni proces za registre
    process (clk, reset)
    begin
        if reset = '1' then
            state_reg <= idle;
            -- Resetovanje svih signala na po?etne vrednosti
            i_reg <= (others => '0');
            j_reg <= (others => '0');
            ri <= (others => '0');
            ci <= (others => '0');
            addSampleStep <= (others => '0');
            r <= (others => '0');
            c <= (others => '0');
            rpos <= (others => '0');
            cpos <= (others => '0');
            rx <= (others => '0');
            cx <= (others => '0');
            rfrac <= (others => '0');
            cfrac <= (others => '0');
            dx <= (others => '0');
            dy <= (others => '0');
            dxx <= (others => '0');
            dyy <= (others => '0');
            weight <= (others => '0');
            rweight1 <= (others => '0');
            rweight2 <= (others => '0');
            cweight1 <= (others => '0');
            cweight2 <= (others => '0');
            ori1 <= (others => '0');
            ori2 <= (others => '0');
            dxx1 <= (others => '0');
            dxx2 <= (others => '0');
            dyy1 <= (others => '0');
            dyy2 <= (others => '0');
            data1_o_reg <= (others => '0');
            data2_o_reg <= (others => '0');
            bram_addr1_int <= (others => '0');
            bram_addr2_int <= (others => '0');
            -- Resetovanje registara
            dxx1_sum_reg <= (others => '0');
            dxx2_sum_reg <= (others => '0');
            dyy1_sum_reg <= (others => '0');
            dyy2_sum_reg <= (others => '0');
        elsif (rising_edge(clk)) then
            state_reg <= state_next;
            -- A�uriranje registara sa internim signalima
            i_reg <= i_next;
            j_reg <= j_next;
            ri <= ri_next;
            ci <= ci_next;
            addSampleStep <= addSampleStep_next;
            r <= r_next;
            c <= c_next;
            rpos <= rpos_next;
            cpos <= cpos_next;
            rx <= rx_next;
            cx <= cx_next;
            rfrac <= rfrac_next;
            cfrac <= cfrac_next;
            dx <= dx_next;
            dy <= dy_next;
            dxx <= dxx_next;
            dyy <= dyy_next;
            weight <= weight_next;
            rweight1 <= rweight1_next;
            rweight2 <= rweight2_next;
            cweight1 <= cweight1_next;
            cweight2 <= cweight2_next;
            ori1 <= ori1_next;
            ori2 <= ori2_next;
            dxx1 <= dxx1_next;
            dxx2 <= dxx2_next;
            dyy1 <= dyy1_next;
            dyy2 <= dyy2_next;
            dxx1_sum_reg <= dxx1_sum_next;
            dxx2_sum_reg <= dxx2_sum_next;
            dyy1_sum_reg <= dyy1_sum_next;
            dyy2_sum_reg <= dyy2_sum_next;
            data1_o_reg <= data1_o_next_int;
            data2_o_reg <= data2_o_next_int;
            bram_addr1_int <= bram_addr1_next;  -- A�uriranje internog signala za adrese
            bram_addr2_int <= bram_addr2_next;
        end if;
    end process;

    -- Kombinacioni proces za odre?ivanje slede?ih stanja i vrednosti signala
    process (state_reg, start_i, bram_data1_i, bram_data2_i, iradius, fracr, fracc, spacing, iy, ix, step, i_cose, i_sine, scale, i_reg, j_reg, ri, ci, r, c, rx, cx, rfrac, cfrac, dx, dy, dxx, dyy, weight, rweight1, rweight2, cweight1, cweight2, ori1, ori2, dxx1, dxx2, dyy1, dyy2, rpos, cpos, dxx1_sum_reg, dxx2_sum_reg, dyy1_sum_reg, dyy2_sum_reg, addSampleStep, addSampleStep_next, r_next, c_next, rom_data, data1_o_reg, data2_o_reg, bram_addr1_int, bram_addr2_int, bram_addr1_next, bram_addr2_next, dxx1_sum_next, dxx2_sum_next, dyy1_sum_next, dyy2_sum_next, dx_next, dy_next, rfrac_next, cfrac_next, j_next, i_next, rx_next, cx_next, dxx1_next, dxx2_next, dyy1_next, dyy2_next, rweight1_next, rweight2_next, cweight1_next, cweight2_next, ori1_next, ori2_next, weight_next, rom_addr_next)
    begin
        -- Default assignments
        state_next <= state_reg;
        i_next <= i_reg;
        j_next <= j_reg;
        ri_next <= ri;
        ci_next <= ci;
        addSampleStep_next <= addSampleStep;
        r_next <= r;
        c_next <= c;
        rx_next <= rx;
        cx_next <= cx;
        rfrac_next <= rfrac;
        cfrac_next <= cfrac;
        dx_next <= dx;
        dy_next <= dy;
        dxx_next <= dxx;
        dyy_next <= dyy;
        weight_next <= weight;
        rweight1_next <= rweight1;
        rweight2_next <= rweight2;
        cweight1_next <= cweight1;
        cweight2_next <= cweight2;
        ori1_next <= ori1;
        ori2_next <= ori2;
        dxx1_next <= dxx1;
        dxx2_next <= dxx2;
        dyy1_next <= dyy1;
        dyy2_next <= dyy2;
        rpos_next <= rpos;
        cpos_next <= cpos;
        data1_o_next_int <= data1_o_reg;  -- Interni signal za kombinatornu logiku
        data2_o_next_int <= data2_o_reg;
        dxx1_sum_next <= dxx1_sum_reg;
        dxx2_sum_next <= dxx2_sum_reg;
        dyy1_sum_next <= dyy1_sum_reg;
        dyy2_sum_next <= dyy2_sum_reg;
        bram_addr1_next <= bram_addr1_int;  -- A�uriranje internog signala za adrese
        bram_addr2_next <= bram_addr2_int;
        
        bram_en1_o <= '0'; -- Defaultna vrednost za bram_en1_o
        bram_we1_o <= '0'; -- Defaultna vrednost za bram_we1_o
        bram_en2_o <= '0'; -- Defaultna vrednost za bram_en2_o
        bram_we2_o <= '0'; -- Defaultna vrednost za bram_we2_o
        rom_addr_next <= (others => '0'); -- Defaultna vrednost za rom_addr
        addr_do1_o <= (others => '0'); -- Defaultna vrednost za addr_do1_o
        addr_do2_o <= (others => '0'); -- Defaultna vrednost za addr_do2_o

        c1_data_o <= '0';
        c2_data_o <= '0';
        ready_o <= '1';

        -- Logika FSM-a
        case state_reg is
            when idle =>
                ready_o <= '1';
                if start_i = '1' then
                    i_next <= TO_UNSIGNED (0, WIDTH);

                    state_next <= StartLoop;
                else
                    state_next <= idle;
                end if;

            when StartLoop =>
                j_next <= TO_UNSIGNED (0, WIDTH);
                state_next <= InnerLoop;

            when InnerLoop =>
                -- Compute positions
                rpos_next <= std_logic_vector(
                    resize(
                        to_unsigned(
                            (to_integer(unsigned(step)) *
                             (-to_integer(unsigned(i_cose)) * (to_integer(signed(i_reg)) - to_integer(signed(iradius))) + 
                              to_integer(unsigned(i_sine)) * (to_integer(signed(j_reg)) - to_integer(signed(iradius)))) -
                             to_integer(unsigned(fracc))) / to_integer(unsigned(spacing)),
                        FIXED_SIZE
                    ),
                    FIXED_SIZE
                ));
                
                cpos_next <= std_logic_vector(
                    resize(
                        to_unsigned(
                            (to_integer(unsigned(step)) *
                             (-to_integer(unsigned(i_sine)) * (to_integer(signed(i_reg)) - to_integer(signed(iradius))) + 
                              to_integer(unsigned(i_cose)) * (to_integer(signed(j_reg)) - to_integer(signed(iradius)))) -
                             to_integer(unsigned(fracc))) / to_integer(unsigned(spacing)),
                        FIXED_SIZE
                    ),
                    FIXED_SIZE
                ));
                
                rx_next <= std_logic_vector(to_unsigned(to_integer(unsigned(rpos)), rpos'length) + to_unsigned(0, rpos'length) / 2 - 1);
                cx_next <= std_logic_vector(to_unsigned(to_integer(unsigned(cpos)), cpos'length) + to_unsigned(0, cpos'length) / 2 - 1);
                state_next <= BoundaryCheck;

            when BoundaryCheck =>
                if to_integer(unsigned(rx)) <= -1 or to_integer(unsigned(rx)) >= INDEX_SIZE or to_integer(unsigned(cx)) <= -1 or to_integer(unsigned(cx)) >= INDEX_SIZE then
                    state_next <= NextSample;
                else
                    state_next <= PositionValidation;
                end if;

            when PositionValidation =>
                addSampleStep_next <= unsigned(resize(signed(scale), WIDTH));
                r_next <= resize(signed(iy) + (signed(resize(i_reg, WIDTH)) - signed(resize(iradius, WIDTH))) * signed(step), WIDTH);
                c_next <= resize(signed(ix) + (signed(resize(j_reg, WIDTH)) - signed(resize(iradius, WIDTH))) * signed(step), WIDTH);

                if (r_next < 1 + signed(addSampleStep) or r_next >= IMG_HEIGHT - 1 - signed(addSampleStep) or
                    c_next < 1 + signed(addSampleStep) or c_next >= IMG_WIDTH - 1 - signed(addSampleStep)) then
                    state_next <= NextSample;
                else
                    state_next <= ProcessSample;
                end if;

            when ProcessSample =>
                rom_addr_next <= std_logic_vector(to_unsigned(to_integer(unsigned(rpos) * unsigned(rpos) + unsigned(cpos) * unsigned(cpos)), 6)); -- Izra?unavanje adrese za ROM
                weight_next <= rom_data;  -- ?itanje te�ine direktno iz ROM-a
                state_next <= ComputeDerivatives;

            when ComputeDerivatives =>
                -- Set BRAM addresses for the first pair of pixels for dxx1
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r) + to_integer(addSampleStep) + 1) * IMG_WIDTH + (to_integer(c) + to_integer(addSampleStep) + 1), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r) - to_integer(addSampleStep)) * IMG_WIDTH + to_integer(c), PIXEL_SIZE));
                bram_en1_o <= '1';  -- Enable BRAM port 1
                bram_en2_o <= '1';  -- Enable BRAM port 2
                state_next <= FetchDXX1_1;

            when FetchDXX1_1 =>
                -- Capture the data from BRAM for dxx1
                dxx1_sum_next <= std_logic_vector(resize(signed(dxx1_sum_reg), FIXED_SIZE) + resize(signed(bram_data1_i), FIXED_SIZE) + resize(signed(bram_data2_i), FIXED_SIZE));
                -- Set BRAM addresses for the second pair of pixels for dxx1
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r) - to_integer(addSampleStep)) * IMG_WIDTH + (to_integer(c) + to_integer(addSampleStep) + 1), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r) + to_integer(addSampleStep) + 1) * IMG_WIDTH + to_integer(c), PIXEL_SIZE));
                state_next <= FetchDXX1_2;

            when FetchDXX1_2 =>
                -- Capture the data from BRAM for dxx1
                dxx1_sum_next <= std_logic_vector(resize(signed(dxx1_sum_next), FIXED_SIZE) - resize(signed(bram_data1_i), FIXED_SIZE) - resize(signed(bram_data2_i), FIXED_SIZE));
                state_next <= ComputeDXX1;

            when ComputeDXX1 =>
                -- Final computation for dxx1
                dxx1_next <= dxx1_sum_next;
                -- Set BRAM addresses for the first pair of pixels for dxx2
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r) + to_integer(addSampleStep) + 1) * IMG_WIDTH + to_integer(c + 1), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r) - to_integer(addSampleStep)) * IMG_WIDTH + (to_integer(c) - to_integer(addSampleStep)), PIXEL_SIZE));
                state_next <= FetchDXX2_1;

            when FetchDXX2_1 =>
                -- Capture the data from BRAM for dxx2
                dxx2_sum_next <= std_logic_vector(resize(signed(dxx2_sum_reg), FIXED_SIZE) + resize(signed(bram_data1_i), FIXED_SIZE) + resize(signed(bram_data2_i), FIXED_SIZE));
                -- Set BRAM addresses for the second pair of pixels for dxx2
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r) - to_integer(addSampleStep)) * IMG_WIDTH + (to_integer(c) + 1), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r) + to_integer(addSampleStep) + 1) * IMG_WIDTH + to_integer(c - to_integer(addSampleStep)), PIXEL_SIZE));
                state_next <= FetchDXX2_2;

            when FetchDXX2_2 =>
                -- Capture the data from BRAM for dxx2
                dxx2_sum_next <= std_logic_vector(resize(signed(dxx2_sum_next), FIXED_SIZE) - resize(signed(bram_data1_i), FIXED_SIZE) - resize(signed(bram_data2_i), FIXED_SIZE));
                state_next <= ComputeDXX2;

            when ComputeDXX2 =>
                -- Final computation for dxx2
                dxx2_next <= dxx2_sum_next;
                -- Set BRAM addresses for the first pair of pixels for dyy1
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r + 1) * IMG_WIDTH + to_integer(c - to_integer(addSampleStep))), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r - to_integer(addSampleStep)) * IMG_WIDTH + to_integer(c + to_integer(addSampleStep) + 1)), PIXEL_SIZE));
                state_next <= FetchDYY1_1;

            when FetchDYY1_1 =>
                -- Capture the data from BRAM for dyy1
                dyy1_sum_next <= std_logic_vector(resize(signed(dyy1_sum_reg), FIXED_SIZE) + resize(signed(bram_data1_i), FIXED_SIZE) + resize(signed(bram_data2_i), FIXED_SIZE));
                -- Set BRAM addresses for the second pair of pixels for dyy1
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r + 1) * IMG_WIDTH + to_integer(c - to_integer(addSampleStep))), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned((to_integer(r - to_integer(addSampleStep)) * IMG_WIDTH + to_integer(c + to_integer(addSampleStep) + 1)), PIXEL_SIZE));
                state_next <= FetchDYY1_2;

            when FetchDYY1_2 =>
                -- Capture the data from BRAM for dyy1
                dyy1_sum_next <= std_logic_vector(resize(signed(dyy1_sum_next), FIXED_SIZE) - resize(signed(bram_data1_i), FIXED_SIZE) - resize(signed(bram_data2_i), FIXED_SIZE));
                state_next <= ComputeDYY1;

            when ComputeDYY1 =>
                -- Final computation for dyy1
                dyy1_next <= dyy1_sum_next;
                -- Set BRAM addresses for the first pair of pixels for dyy2
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r + to_integer(addSampleStep) + 1) * IMG_WIDTH + to_integer(c + to_integer(addSampleStep) + 1)), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned(to_integer(r) * IMG_WIDTH + to_integer(c - to_integer(addSampleStep)), PIXEL_SIZE));
                state_next <= FetchDYY2_1;

            when FetchDYY2_1 =>
                -- Capture the data from BRAM for dyy2
                dyy2_sum_next <= std_logic_vector(resize(signed(dyy2_sum_reg), FIXED_SIZE) + resize(signed(bram_data1_i), FIXED_SIZE) + resize(signed(bram_data2_i), FIXED_SIZE));
                -- Set BRAM addresses for the second pair of pixels for dyy2
                bram_addr1_next <= std_logic_vector(to_unsigned((to_integer(r + to_integer(addSampleStep) + 1) * IMG_WIDTH + to_integer(c - to_integer(addSampleStep))), PIXEL_SIZE));
                bram_addr2_next <= std_logic_vector(to_unsigned(to_integer(r) * IMG_WIDTH + to_integer(c + to_integer(addSampleStep) + 1), PIXEL_SIZE));
                state_next <= FetchDYY2_2;

            when FetchDYY2_2 =>
                -- Capture the data from BRAM for dyy2
                dyy2_sum_next <= std_logic_vector(resize(signed(dyy2_sum_next), FIXED_SIZE) - resize(signed(bram_data1_i), FIXED_SIZE) - resize(signed(bram_data2_i), FIXED_SIZE));
                state_next <= ComputeDYY2;

            when ComputeDYY2 =>
                -- Final computation for dyy2
                dyy2_next <= dyy2_sum_next;
                state_next <= CalculateDerivatives;

            when CalculateDerivatives =>
                dxx_next <= std_logic_vector(resize(signed(weight) * (signed(dxx1) - signed(dxx2)), FIXED_SIZE)); -- ILI MO�DA 2 PUTA FIXED_SIZE
                dyy_next <= std_logic_vector(resize(signed(weight) * (signed(dyy1) - signed(dyy2)), FIXED_SIZE));
                state_next <= ApplyOrientationTransform;

            when ApplyOrientationTransform =>
                dx_next <= std_logic_vector(resize(signed(i_cose) * signed(dxx) + signed(i_sine) * signed(dyy), FIXED_SIZE));
                dy_next <= std_logic_vector(resize(signed(i_sine) * signed(dxx) - signed(i_cose) * signed(dyy), FIXED_SIZE));
                state_next <= SetOrientations;

            when SetOrientations =>
                if signed(dx_next) < 0 then
                    ori1_next <= to_unsigned(0, WIDTH);
                else
                    ori1_next <= to_unsigned(1, WIDTH);
                end if;
                if signed(dy_next) < 0 then
                    ori2_next <= to_unsigned(2, WIDTH);
                else
                    ori2_next <= to_unsigned(3, WIDTH);
                end if;
                state_next <= UpdateIndex;

            when UpdateIndex =>
                -- Check rx and set ri accordingly
                if signed(rx) < 0 then
                    ri_next <= to_unsigned(0, WIDTH);
                elsif signed(rx) >= INDEX_SIZE then
                    ri_next <= to_unsigned(INDEX_SIZE - 1, WIDTH);
                else
                    ri_next <= to_unsigned(to_integer(signed(rx)), WIDTH);
                end if;

                -- Check ci and update ci accordingly
                if signed(cx) < 0 then
                    ci_next <= to_unsigned(0, WIDTH);
                elsif signed(cx) >= INDEX_SIZE then
                    ci_next <= to_unsigned(INDEX_SIZE - 1, WIDTH);
                else
                    ci_next <= to_unsigned(to_integer(signed(cx)), WIDTH);
                end if;

                -- Compute fractional components
                rfrac_next <= std_logic_vector(signed(rx) - signed(ri));
                cfrac_next <= std_logic_vector(signed(cx) - signed(ci));

                if signed(rfrac_next) < 0 then
                    rfrac_next <= std_logic_vector(to_signed(0, rfrac_next'length));
                elsif signed(rfrac_next) >= 2**WIDTH then
                    rfrac_next <= std_logic_vector(to_signed(2**WIDTH - 1, rfrac_next'length));
                end if;

                if signed(cfrac_next) < 0 then
                    cfrac_next <= std_logic_vector(to_signed(0, cfrac_next'length));
                elsif signed(cfrac_next) >= 2**WIDTH then
                    cfrac_next <= std_logic_vector(to_signed(2**WIDTH - 1, cfrac_next'length));
                end if;

                state_next <= ComputeWeights;

            when ComputeWeights =>
                rweight1_next <= std_logic_vector(resize(unsigned(dx) * (unsigned((2**WIDTH - 1) - unsigned(rfrac_next))), FIXED_SIZE));
                rweight2_next <= std_logic_vector(resize(unsigned(dx) * unsigned(rfrac_next), FIXED_SIZE));
                cweight1_next <= std_logic_vector(resize(unsigned(rweight1) * (unsigned((2**WIDTH - 1) - unsigned(cfrac_next))), FIXED_SIZE));
                cweight2_next <= std_logic_vector(resize(unsigned(rweight2) * unsigned(cfrac_next), FIXED_SIZE));
                state_next <= UpdateIndexArray;

            when UpdateIndexArray =>
                if ri >= 0 and ri < INDEX_SIZE and ci >= 0 and ci < INDEX_SIZE then
                    addr_do1_o <= std_logic_vector(to_unsigned((to_integer(unsigned(ri)) * (INDEX_SIZE * 4)) + to_integer(unsigned(ci)) * 4 + to_integer(unsigned(ori1)), addr_do1_o'length));
                    data1_o_next_int <= std_logic_vector(resize(unsigned(data1_o_reg) + unsigned(cweight1), data1_o_next_int'length));  -- Kori�?enje internog signala
                    c1_data_o <= '1';

                    addr_do2_o <= std_logic_vector(to_unsigned((to_integer(unsigned(ri)) * (INDEX_SIZE * 4)) + to_integer(unsigned(ci)) * 4 + to_integer(unsigned(ori2)), addr_do1_o'length));
                    data2_o_next_int <= std_logic_vector(resize(unsigned(data2_o_reg) + unsigned(cweight2), data2_o_next_int'length));  -- Kori�?enje internog signala
                    c2_data_o <= '1';

                    state_next <= CheckNextColumn;
                end if;

            when CheckNextColumn =>
                if ci + 1 < INDEX_SIZE then
                    addr_do1_o <= std_logic_vector(to_unsigned(to_integer(unsigned(ri)) * (INDEX_SIZE * 4) + to_integer(unsigned(ci+1)) * 4 + to_integer(unsigned(ori1)), addr_do1_o'length));
                    data1_o_next_int <= std_logic_vector(unsigned(data1_o_reg) + unsigned(cweight1) * to_unsigned(to_integer(signed(cfrac)), cweight1'length));
                    c1_data_o <= '1';

                    addr_do2_o <= std_logic_vector(to_unsigned(to_integer(unsigned(ri)) * (INDEX_SIZE * 4) + to_integer(unsigned(ci+1)) * 4 + to_integer(unsigned(ori2)), addr_do2_o'length));
                    data2_o_next_int <= std_logic_vector(unsigned(data2_o_reg) + unsigned(cweight2) * to_unsigned(to_integer(signed(cfrac)), cweight2'length));
                    c2_data_o <= '1';

                    state_next <= CheckNextRow;
                end if;

            when CheckNextRow =>
                if ri + 1 < INDEX_SIZE then
                    addr_do1_o <= std_logic_vector(to_unsigned(to_integer(unsigned(ri+1)) * (INDEX_SIZE * 4) + to_integer(unsigned(ci)) * 4 + to_integer(unsigned(ori1)), addr_do1_o'length));
                    data1_o_next_int <= std_logic_vector(unsigned(data1_o_reg) + unsigned(cweight1) * resize(to_unsigned(to_integer(signed(cfrac)), cweight1'length), cweight1'length));
                    c1_data_o <= '1';

                    addr_do2_o <= std_logic_vector(to_unsigned(to_integer(unsigned(ri+1)) * (INDEX_SIZE * 4) + to_integer(unsigned(ci)) * 4 + to_integer(unsigned(ori2)), addr_do1_o'length));
                    data2_o_next_int <= std_logic_vector(unsigned(data2_o_reg) + unsigned(cweight2) * resize(to_unsigned(to_integer(signed(cfrac)), cweight2'length), cweight2'length));
                    c2_data_o <= '1';
                end if;

                state_next <= NextSample;

            when NextSample =>
                j_next <= j_reg + 1;
                if (j_next > to_integer(unsigned(2*iradius))) then
                    state_next <= IncrementI;
                else
                    state_next <= InnerLoop;
                end if;

            when IncrementI =>
                i_next <= i_reg + 1;
                if (i_next > to_integer(unsigned(2*iradius))) then
                    state_next <= Finish;
                else
                    state_next <= StartLoop;
                end if;

            when Finish =>
                done <= '1';
                state_next <= idle;

            when others =>
                state_next <= idle;
        end case;
    end process;

    -- A�uriranje izlaznih portova iz internog signala za adrese
    bram_addr1_o <= bram_addr1_int;
    bram_addr2_o <= bram_addr2_int;
--bram_en1_o <= '1' when state_next /= idle else '0';
  --  bram_we1_o <= '0';
--bram_en2_o <= '1' when state_next /= idle else '0';
   -- bram_we2_o <= '0';
    rom_addr <= rom_addr_next;  -- A�uriranje rom_addr signala

end Behavioral;
