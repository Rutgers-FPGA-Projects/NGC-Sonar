LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL; 
ENTITY final IS
	PORT(
		CLOCK_50 	: IN STD_LOGIC;
		SW				: IN STD_LOGIC_VECTOR(17 DOWNTO 0);
		KEY			: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		LEDG			: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		LEDR			: OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
		GPIO			: INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
      LCD_RS, LCD_EN         : OUT STD_LOGIC;
      LCD_RW                 : OUT STD_LOGIC;
      LCD_ON                 : OUT STD_LOGIC;
      LCD_DATA               : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END final;

ARCHITECTURE arch OF final IS
	function to_bcd ( bin : std_logic_vector(7 downto 0) ) return std_logic_vector is
		variable i : integer:=0;
		variable bcd : std_logic_vector(11 downto 0) := (others => '0');
		variable bint : std_logic_vector(7 downto 0) := bin;
	
		begin
			for i in 0 to 7 loop  -- repeating 8 times.
				bcd(11 downto 1) := bcd(10 downto 0);  --shifting the bits.
				bcd(0) := bint(7);
				bint(7 downto 1) := bint(6 downto 0);
				bint(0) :='0';
	
				if(i < 7 and bcd(3 downto 0) > "0100") then --add 3 if BCD digit is greater than 4.
				bcd(3 downto 0) := STD_LOGIC_VECTOR(UNSIGNED(bcd(3 downto 0)) + 3);
				end if;
		
				if(i < 7 and bcd(7 downto 4) > "0100") then --add 3 if BCD digit is greater than 4.
				bcd(7 downto 4) := STD_LOGIC_VECTOR(UNSIGNED(bcd(7 downto 4)) + 3);
				end if;
	
				if(i < 7 and bcd(11 downto 8) > "0100") then  --add 3 if BCD digit is greater than 4.
				bcd(11 downto 8) := STD_LOGIC_VECTOR(UNSIGNED(bcd(11 downto 8)) + 3);
				end if;
				
			end loop;
		return bcd;
	end to_bcd;

	COMPONENT LCD_Display IS
		PORT( 
		 KEY         : IN STD_LOGIC_VECTOR(0 downto 0);
       CLOCK_50       : IN  STD_LOGIC;
       Hex_Display_Data       : IN    STD_LOGIC_VECTOR(11 DOWNTO 0); --STD_LOGIC_VECTOR((Num_Hex_Digits*4)-1 DOWNTO 0);
       LCD_RS, LCD_EN          : OUT STD_LOGIC;
       LCD_RW                 : OUT   STD_LOGIC;
       LCD_ON                 : OUT STD_LOGIC;
       LCD_DATA               : INOUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		 inch_cent_switch 		: IN STD_LOGIC;
		 lds							: IN STD_LOGIC_VECTOR(15 DOWNTO 0));
	end component;

	COMPONENT bcd IS
		PORT(
			hexin : IN integer;
			decout : OUT STD_LOGIC_VECTOR(11 DOWNTO 0));
	END COMPONENT;

	signal reset: std_Logic; 
	signal trigger : INTEGER:= 500; -- 10us
	signal counter : INTEGER RANGE 0 TO 50000000 := 50000000; -- 30000us
	SIGNAL MAX_CYCLES : INTEGER;
	SIGNAL i 						: INTEGER RANGE 0 TO 65535 := 0;
	signal count_dist: integer; 
	signal hex: std_logic_vector (7 downto 0);
	SIGNAL decimal : STD_LOGIC_VECTOR(11 DOWNTO 0);
	
	SIGNAL inch_conversion_factor : INTEGER := 7231;
	SIGNAL cent_conversion_factor : INTEGER := 2847;
	SIGNAL inch_cent_switch : STD_LOGIC;
	
	SIGNAL max_inches : INTEGER := 120;
	SIGNAL max_centimeters : INTEGER := 300;
	
	SIGNAL sample_speed_switch : STD_LOGIC;
	
	SIGNAL startcount, elapsed : INTEGER;
	SIGNAL graphical_length_display : STD_LOGIC_VECTOR(15 DOWNTO 0);
BEGIN
	reset <= NOT KEY(1);
	inch_cent_switch <= SW(0); -- 0 == inch, 1 == centimeter
	sample_speed_switch <= SW(1);
	
	WITH sample_speed_switch SELECT
		MAX_CYCLES <= 50000000 WHEN '0',
						  12500000 WHEN '1';
	
	PROCESS(RESET, CLOCK_50)
	BEGIN
		IF  RESET='1' THEN                            -- RESET KEY1 PRESS
			 counter<= 0;
		ELSIF Rising_edge(CLOCK_50) THEN                 -- KEY0 ACT AS CLOCK
			counter <= counter +1;
			IF(counter > MAX_CYCLES) THEN
				counter <= 0;
			END IF;
		END IF; 
	END PROCESS;
	
	Process(counter)
	Begin
		IF(counter < trigger) THEN -- 0 to 10us
			-- GPIO(0) <= '0'; -- echo
			GPIO(2) <= '1'; -- trigger
		ELSE
			GPIO(2) <= '0';
		end if; 	
	end process; 
	
	PROCESS(GPIO(0))
	BEGIN
		IF(RISING_EDGE(GPIO(0))) THEN
			startcount <= counter;
		ELSIF(FALLING_EDGE(GPIO(0))) THEN
			elapsed <= counter - startcount; 
			IF(inch_cent_switch = '0') THEN
				count_dist <= elapsed / cent_conversion_factor;
				
				IF(count_dist > (max_centimeters * 15) / 16) THEN
					graphical_length_display <= "1111111111111111";
				ELSIF(count_dist > (max_centimeters * 14) / 16) THEN
					graphical_length_display <= "1111111111111110";
				ELSIF(count_dist > (max_centimeters * 13) / 16) THEN
					graphical_length_display <= "1111111111111100";
				ELSIF(count_dist > (max_centimeters * 12) / 16) THEN
					graphical_length_display <= "1111111111111000";
				ELSIF(count_dist > (max_centimeters * 11) / 16) THEN
					graphical_length_display <= "1111111111110000";
				ELSIF(count_dist > (max_centimeters * 10) / 16) THEN
					graphical_length_display <= "1111111111100000";
				ELSIF(count_dist > (max_centimeters * 9) / 16) THEN
					graphical_length_display <= "1111111111000000";
				ELSIF(count_dist > (max_centimeters * 8) / 16) THEN
					graphical_length_display <= "1111111110000000";
				ELSIF(count_dist > (max_centimeters * 7) / 16) THEN
					graphical_length_display <= "1111111100000000";
				ELSIF(count_dist > (max_centimeters * 6) / 16) THEN
					graphical_length_display <= "1111111000000000";
				ELSIF(count_dist > (max_centimeters * 5) / 16) THEN
					graphical_length_display <= "1111110000000000";
				ELSIF(count_dist > (max_centimeters * 4) / 16) THEN
					graphical_length_display <= "1111100000000000";
				ELSIF(count_dist > (max_centimeters * 3) / 16) THEN
					graphical_length_display <= "1111000000000000";
				ELSIF(count_dist > (max_centimeters * 2) / 16) THEN
					graphical_length_display <= "1110000000000000";
				ELSIF(count_dist > (max_centimeters * 1) / 16) THEN
					graphical_length_display <= "1100000000000000";
				ELSIF(count_dist > (max_centimeters * 0) / 16) THEN
					graphical_length_display <= "1000000000000000";
				END IF;
			ELSIF(inch_cent_switch = '1') THEN
				count_dist <= elapsed / inch_conversion_factor;
				
				IF(count_dist > (max_inches * 15) / 16) THEN
					graphical_length_display <= "1111111111111111";
				ELSIF(count_dist > (max_inches * 14) / 16) THEN
					graphical_length_display <= "1111111111111110";
				ELSIF(count_dist > (max_inches * 13) / 16) THEN
					graphical_length_display <= "1111111111111100";
				ELSIF(count_dist > (max_inches * 12) / 16) THEN
					graphical_length_display <= "1111111111111000";
				ELSIF(count_dist > (max_inches * 11) / 16) THEN
					graphical_length_display <= "1111111111110000";
				ELSIF(count_dist > (max_inches * 10) / 16) THEN
					graphical_length_display <= "1111111111100000";
				ELSIF(count_dist > (max_inches * 9) / 16) THEN
					graphical_length_display <= "1111111111000000";
				ELSIF(count_dist > (max_inches * 8) / 16) THEN
					graphical_length_display <= "1111111110000000";
				ELSIF(count_dist > (max_inches * 7) / 16) THEN
					graphical_length_display <= "1111111100000000";
				ELSIF(count_dist > (max_inches * 6) / 16) THEN
					graphical_length_display <= "1111111000000000";
				ELSIF(count_dist > (max_inches * 5) / 16) THEN
					graphical_length_display <= "1111110000000000";
				ELSIF(count_dist > (max_inches * 4) / 16) THEN
					graphical_length_display <= "1111100000000000";
				ELSIF(count_dist > (max_inches * 3) / 16) THEN
					graphical_length_display <= "1111000000000000";
				ELSIF(count_dist > (max_inches * 2) / 16) THEN
					graphical_length_display <= "1110000000000000";
				ELSIF(count_dist > (max_inches * 1) / 16) THEN
					graphical_length_display <= "1100000000000000";
				ELSIF(count_dist > (max_inches * 0) / 16) THEN
					graphical_length_display <= "1000000000000000";
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	hex <= STD_LOGIC_VECTOR(TO_UNSIGNED(count_dist, 8));
	
	decimal <= to_bcd(hex);
	
	lcd : LCD_Display PORT MAP(KEY(0 downto 0),CLOCK_50, decimal,LCD_RS, LCD_EN,LCD_RW ,LCD_ON,LCD_DATA, inch_cent_switch, graphical_length_display);

	--dispupper : hexdec PORT MAP(hex(7 downto 4), HEX7, '0', '0');
	--displower : hexdec PORT MAP(hex(3 downto 0), HEX0, '0', '0');
END arch;
