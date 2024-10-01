library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bram24_lower_out is
    generic (WIDTH: positive := 24;             -- BRAM ZA IZLAZNE PODATKE DONJIH 24 BITA INDEX NIZA
             SIZE: positive := 4*64;
			 SIZE_WIDTH: positive := 8);
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
end bram24_lower_out;

architecture Behavioral of bram24_lower_out is
    -- Definicija RAM-a kao signala
    type ram_type is array(SIZE-1 downto 0) of std_logic_vector(WIDTH-1 downto 0);
    signal RAM: ram_type;
    
begin

    -- Proces za clka port
    process(clka)
    begin
        if rising_edge(clka) then
            if ena = '1' then
                doa <= RAM(to_integer(unsigned(addra)));
            end if;   

            if wea = '1' then
                RAM(to_integer(unsigned(addra))) <= dia;    
            end if;
        end if;
    end process;              

    -- Proces za clkb port
    process(clkb)
    begin
        if rising_edge(clkb) then
            if enb = '1' then
                dob <= RAM(to_integer(unsigned(addrb)));
            end if;   

            if web = '1' then
                RAM(to_integer(unsigned(addrb))) <= dib;    
            end if;
        end if;
    end process;

end Behavioral;
