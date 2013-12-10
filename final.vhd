LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL; 
ENTITY final IS
	PORT(
		CLOCK_50 	: IN STD_LOGIC; -- 50MHz
		SW				: IN STD_LOGIC_VECTOR(17 DOWNTO 0);
		KEY			: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		LEDG			: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		LEDR			: OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
		GPIO			: INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		-- LCD controller stuff
      LCD_RS, LCD_EN         : OUT STD_LOGIC;
      LCD_RW                 : OUT STD_LOGIC;
      LCD_ON                 : OUT STD_LOGIC;
      LCD_DATA               : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END final;

ARCHITECTURE arch OF final IS
	-- convert our 2 digits of hex to 3 digits of BCD
	FUNCTION to_bcd ( bin : STD_LOGIC_VECTOR(7 DOWNTO 0) ) RETURN STD_LOGIC_VECTOR IS
		VARIABLE i : integer:=0;
		VARIABLE bcd : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
		VARIABLE bint : STD_LOGIC_VECTOR(7 DOWNTO 0) := bin;
	
		BEGIN
			FOR i IN 0 TO 7 LOOP  -- repeating 8 times.
				bcd(11 DOWNTO 1) := bcd(10 DOWNTO 0);  --shifting the bits.
				bcd(0) := bint(7);
				bint(7 DOWNTO 1) := bint(6 DOWNTO 0);
				bint(0) :='0';
	
				IF(i < 7 and bcd(3 DOWNTO 0) > "0100") THEN --add 3 if BCD digit is greater than 4.
				bcd(3 DOWNTO 0) := STD_LOGIC_VECTOR(UNSIGNED(bcd(3 DOWNTO 0)) + 3);
				END IF;
				
				IF(i < 7 and bcd(7 DOWNTO 4) > "0100") THEN --add 3 if BCD digit is greater than 4.
				bcd(7 DOWNTO 4) := STD_LOGIC_VECTOR(UNSIGNED(bcd(7 DOWNTO 4)) + 3);
				END IF;
				
				IF(i < 7 and bcd(11 DOWNTO 8) > "0100") THEN --add 3 if BCD digit is greater than 4.
				bcd(11 DOWNTO 8) := STD_LOGIC_VECTOR(UNSIGNED(bcd(11 DOWNTO 8)) + 3);
				END IF;
				
			END LOOP;
		RETURN bcd;
	END to_bcd;
	
	-- LCD display controller
	COMPONENT LCD_Display IS
		PORT( 
		 KEY         : IN STD_LOGIC_VECTOR(0 downto 0);
       CLOCK_50       : IN  STD_LOGIC;
       Hex_Display_Data       : IN    STD_LOGIC_VECTOR(11 DOWNTO 0); --STD_LOGIC_VECTOR((Num_Hex_Digits*4)-1 DOWNTO 0);
       LCD_RS, LCD_EN         : OUT STD_LOGIC;
       LCD_RW                 : OUT   STD_LOGIC;
       LCD_ON                 : OUT STD_LOGIC;
       LCD_DATA               : INOUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		 inch_cent_switch 		: IN STD_LOGIC;
		 lds							: IN STD_LOGIC_VECTOR(15 DOWNTO 0));
	END COMPONENT;
	
	SIGNAL graphical_length_display : STD_LOGIC_VECTOR(15 DOWNTO 0);

	SIGNAL reset: STD_LOGIC; 
	SIGNAL trigger : INTEGER:= 500; -- 10us
	SIGNAL counter : INTEGER;
	
	SIGNAL MAX_CYCLES : INTEGER; -- number of cycles per sample cycle
	
	SIGNAL count_dist: INTEGER; -- number of in/cm
	SIGNAL hex: STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL decimal : STD_LOGIC_VECTOR(11 DOWNTO 0);
	
	SIGNAL inch_conversion_factor : INTEGER := 7231;
	SIGNAL cent_conversion_factor : INTEGER := 2847;
	
	SIGNAL inch_cent_switch : STD_LOGIC;
	SIGNAL sample_speed_switch : STD_LOGIC;
	
	SIGNAL max_inches : INTEGER := 120;
	SIGNAL max_centimeters : INTEGER := 300;
	
	SIGNAL startcount, elapsed : INTEGER;
	
BEGIN
	reset <= NOT KEY(1);
	inch_cent_switch <= SW(0); -- 0 = inch, 1 = centimeter
	sample_speed_switch <= SW(1);
	
	-- set sample rate
	WITH sample_speed_switch SELECT
		MAX_CYCLES <= 50000000 WHEN '0', -- 1 sample per second
						  12500000 WHEN '1'; -- 4 samples per second
	
	-- sampling cycle loop
	-- increments counter variable and resets when sampling cycle is over
	PROCESS(RESET, CLOCK_50)
	BEGIN
		IF  reset='1' THEN          
			 counter<= 0;
		ELSIF RISING_EDGE(CLOCK_50) THEN
			counter <= counter +1;
			IF(counter > MAX_CYCLES) THEN
				counter <= 0;
			END IF;
		END IF; 
	END PROCESS;
	
	-- trigger signal
	PROCESS(counter)
	BEGIN
		IF(counter < trigger) THEN -- 0 to 10us
			GPIO(2) <= '1'; -- trigger
		ELSE
			GPIO(2) <= '0';
		END IF;
	END PROCESS;
	
	-- echo signal listener
	PROCESS(GPIO(0))
	BEGIN
		IF(RISING_EDGE(GPIO(0))) THEN
			startcount <= counter;
		ELSIF(FALLING_EDGE(GPIO(0))) THEN
			elapsed <= counter - startcount; -- gets length of echo pulse
			IF(inch_cent_switch = '0') THEN
				count_dist <= elapsed / cent_conversion_factor; -- convert length in clocks to length in centimeters
				
				-- determine bar length for display
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
				count_dist <= elapsed / inch_conversion_factor; -- convert length in clocks to length in inches
				
				-- determine bar length for display
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
	
	-- get hex out of integer
	hex <= STD_LOGIC_VECTOR(TO_UNSIGNED(count_dist, 8));
	
	-- get BCD out of hex
	decimal <= to_bcd(hex);
	
	-- instantiate LCD controller
	lcd : LCD_Display PORT MAP(KEY(0 DOWNTO 0),CLOCK_50, decimal,LCD_RS, LCD_EN,LCD_RW ,LCD_ON,LCD_DATA, inch_cent_switch, graphical_length_display);
END arch;
