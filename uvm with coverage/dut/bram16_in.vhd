library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bram16_in is
    generic (WIDTH: positive := 16;                    ---- BRAM ZA DONJIH 16 BITA ZA ULAZNE PODATKE PIXELS1D
             SIZE: positive := 129*129*4;
			 SIZE_WIDTH: positive := 17);
    port (clka : in std_logic;
          clkb : in std_logic;
          ena: in std_logic;
          enb: in std_logic;
          wea: in std_logic;
          web: in std_logic;
          addra: in std_logic_vector(SIZE_WIDTH-1 downto 0);
          addrb: in std_logic_vector(SIZE_WIDTH-1 downto 0);
          dia: in std_logic_vector(WIDTH-1 downto 0);
          dib: in std_logic_vector(WIDTH-1 downto 0);
          doa: out std_logic_vector(WIDTH-1 downto 0);
          dob: out std_logic_vector(WIDTH-1 downto 0));
end bram16_in;

architecture Behavioral of bram16_in is
    type ram_type is array(SIZE-1 downto 0) of std_logic_vector(WIDTH-1 downto 0);
    signal RAM: ram_type;
    
    attribute ram_style: string;
    attribute ram_style of RAM: signal is "block";
begin
    process(clka, clkb)
    begin
        if (rising_edge(clka)) then
            if (ena = '1') then
                doa <= RAM(to_integer(unsigned(addra)));
                if (wea = '1') then
                    RAM(to_integer(unsigned(addra))) <= dia;
                end if;
            end if;
        end if;
        
        if (rising_edge(clkb)) then
            if (enb = '1') then
                dob <= RAM(to_integer(unsigned(addrb)));
                if (web = '1') then
                    RAM(to_integer(unsigned(addrb))) <= dib;
                end if;
            end if;
        end if;
    end process;
end Behavioral;