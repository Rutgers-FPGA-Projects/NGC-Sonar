LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL; 
ENTITY final IS
	PORT(
		CLOCK_50 : IN STD_LOGIC;
		KEY	: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		LEDG	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		LEDR	: OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
		GPIO	: INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		HEX7, HEX0 : BUFFER STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END final;

ARCHITECTURE arch OF final IS

COMPONENT hexdec IS -- 7seg decoder
	PORT(
		bcd7seg_in	: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		bcd7seg_out	: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		set_to_dash : IN STD_LOGIC;
		set_to_null : IN STD_LOGIC);
	END COMPONENT;
	signal reset: std_Logic; 
	signal trigger : INTEGER:= 250; -- 5us
	signal pause_for_input : INTEGER:= 37500; -- 750us
	signal min_input : INTEGER := 1000; -- 115 us
	signal max_input : INTEGER := 925000; -- 18500 us
	signal counter : INTEGER RANGE 0 TO 50000000 := 50000000; -- 30000us
	SIGNAL i 						: INTEGER RANGE 0 TO 65535 := 0;
	signal count_dist: integer; 
	signal hex: std_logic_vector (7 downto 0);
BEGIN

	reset <= Not key(1);
	PROCESS(RESET, CLOCK_50)
	BEGIN
		IF  RESET='1' THEN                            -- RESET KEY1 PRESS
			 counter<= 0;

		ELSIF Rising_edge(CLOCK_50) THEN                 -- KEY0 ACT AS CLOCK
			counter <= counter +1;
		END IF; 
	END PROCESS;	
	Process(GPIO(0),counter)
	Begin
		IF(counter < trigger) THEN
			GPIO(0) <='1';
			count_dist <= 0; 
		ELSIF(counter = trigger ) THEN
			GPIO(0) <= '0';
			LEDR(0)<='1';
			LEDR(1)<='0';
			LEDG(0)<='0';
		ELSIF(counter >= (pause_for_input + trigger)) THEN
			LEDR(1)<='1';
			LEDR(0)<='0';
			LEDG(0)<='0';
			IF(GPIO(0) = '1') THEN
				IF(i < 7231) THEN
					i <= i + 1;
				END IF;
				IF(i = 7231) THEN
					count_dist <= count_dist + 1;
					LEDG(0)<='1';
					i <= 0;
				END IF;
			END IF;
		end if; 	
	end process; 
	hex <= STD_LOGIC_VECTOR(TO_UNSIGNED(count_dist, 8));
				
	
	dispupper : hexdec PORT MAP(hex(7 downto 4), HEX7, '0', '0');
	displower : hexdec PORT MAP(hex(3 downto 0), HEX0, '0', '0');
END arch;
	
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL; 

ENTITY hexdec IS -- 7seg decoder
	PORT(
		bcd7seg_in	: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		bcd7seg_out	: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		set_to_dash : IN STD_LOGIC;
		set_to_null : IN STD_LOGIC);
END hexdec;

ARCHITECTURE dodecode OF hexdec IS
BEGIN
	PROCESS(bcd7seg_in)
	BEGIN
		IF(set_to_null = '1') THEN -- blank display
			bcd7seg_out <= "1111111";
		ELSIF(set_to_dash = '1') THEN -- dash across middle
			bcd7seg_out <= "0111111";
		ELSE -- standard 7segment decoder
			CASE bcd7seg_in IS
				WHEN "0000" => bcd7seg_out <=	"1000000";
				WHEN "0001" => bcd7seg_out <=	"1111001";
				WHEN "0010" => bcd7seg_out <=	"0100100";
				WHEN "0011" => bcd7seg_out <=	"0110000";
				WHEN "0100" => bcd7seg_out <=	"0011001";
				WHEN "0101" => bcd7seg_out <=	"0010010";
				WHEN "0110" => bcd7seg_out <=	"0000010";
				WHEN "0111" => bcd7seg_out <=	"1111000";
				WHEN "1000" => bcd7seg_out <=	"0000000";
				WHEN "1001" => bcd7seg_out <=	"0010000";
				WHEN "1010" => bcd7seg_out <=	"0001000";
				WHEN "1011" => bcd7seg_out <=	"0000011";
				WHEN "1100" => bcd7seg_out <=	"1000110";
				WHEN "1101" => bcd7seg_out <=	"0100001";
				WHEN "1110" => bcd7seg_out <=	"0000110";
				WHEN "1111" => bcd7seg_out <=	"0001110";
				WHEN OTHERS => bcd7seg_out <=	"1111111";
			END CASE;
		END IF;
	END PROCESS;
END dodecode;