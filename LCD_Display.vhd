LIBRARY IEEE;
USE  IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;
 
ENTITY LCD_Display IS
-- Enter number of live Hex hardware data values to display
-- (do not count ASCII character constants)
   GENERIC(Num_Hex_Digits: Integer:= 3); 
-----------------------------------------------------------------------
-- LCD Displays 16 Characters on 2 lines
-- LCD_display string is an ASCII character string entered in hex for 
-- the two lines of the  LCD Display   (See ASCII to hex table below)
-- Edit LCD_Display_String entries above to modify display
-- Enter the ASCII character's 2 hex digit equivalent value
-- (see table below for ASCII hex values)
-- To display character assign ASCII value to LCD_display_string(x)
-- To skip a character use X"20" (ASCII space)
-- To dislay "live" hex values from hardware on LCD use the following: 
--   make array element for that character location X"0" & 4-bit field from Hex_Display_Data
--   state machine sees X"0" in high 4-bits & grabs the next lower 4-bits from Hex_Display_Data input
--   and performs 4-bit binary to ASCII conversion needed to print a hex digit
--   Num_Hex_Digits must be set to the count of hex data characters (ie. "00"s) in the display
--   Connect hardware bits to display to Hex_Display_Data input
-- To display less than 32 characters, terminate string with an entry of X"FE"
--  (fewer characters may slightly increase the LCD's data update rate)
------------------------------------------------------------------- 
--                        ASCII HEX TABLE
--  Hex                 Low Hex Digit
-- Value  0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
------\----------------------------------------------------------------
--H  2 |  SP  !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
--i  3 |  0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
--g  4 |  @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
--h  5 |  P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
--   6 |  `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
--   7 |  p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~ DEL
-----------------------------------------------------------------------
-- Example "A" is row 4 column 1, so hex value is X"41"
-- *see LCD Controller's Datasheet for other graphics characters available
--
   PORT( KEY         : IN STD_LOGIC_VECTOR(0 downto 0);
       CLOCK_50       : IN  STD_LOGIC;
       Hex_Display_Data       : IN    STD_LOGIC_VECTOR((Num_Hex_Digits*4)-1 DOWNTO 0);
       LCD_RS, LCD_EN          : OUT STD_LOGIC;
       LCD_RW                 : OUT   STD_LOGIC;
       LCD_ON                 : OUT STD_LOGIC;
       LCD_DATA               : INOUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		 inch_cent_switch			: IN STD_LOGIC; -- 0 == inch, 1 == cent
		 lds							: IN STD_LOGIC_VECTOR(15 DOWNTO 0) -- length display string
		 );
      
END ENTITY LCD_Display;

ARCHITECTURE Behavior OF LCD_Display IS
TYPE character_string IS ARRAY ( 0 TO 31 ) OF STD_LOGIC_VECTOR( 7 DOWNTO 0 );

TYPE STATE_TYPE IS (HOLD, FUNC_SET, DISPLAY_ON, MODE_SET, Print_String,
               LINE2, RETURN_HOME, DROP_LCD_EN, RESET1, RESET2, 
               RESET3, DISPLAY_OFF, DISPLAY_CLEAR);

SIGNAL   state, next_command           : STATE_TYPE;
SIGNAL   LCD_display_string            : character_string;

-- Enter new ASCII hex data above for LCD Display
SIGNAL         reset        : std_logic;
SIGNAL   LCD_DATA_VALUE, Next_Char     : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL   CLK_COUNT_400HZ               : STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL   CHAR_COUNT                 : STD_LOGIC_VECTOR(4 DOWNTO 0);
SIGNAL   CLK_400HZ_Enable,LCD_RW_INT   : STD_LOGIC;
SIGNAL   Line1_chars, Line2_chars      : STD_LOGIC_VECTOR(127 DOWNTO 0);

FUNCTION ldd(inbit : STD_LOGIC) RETURN STD_LOGIC_VECTOR IS -- length display decode
	VARIABLE disp_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
	IF(inbit = '0') THEN
		disp_out := "00100000";
	ELSIF(inbit = '1') THEN
		disp_out := "00100011";
	END IF;
	RETURN disp_out;
END ldd;

BEGIN

LCD_ON      <= '1';
-- LCD_BLON    <= '1'; backlight unused
reset <= KEY(0);

-- ASCII hex values for LCD Display
-- Enter Live Hex Data Values from hardware here
-- LCD DISPLAYS THE FOLLOWING:
------------------------------
--| Count=XX                  |
--| DE2                       |
------------------------------
WITH inch_cent_switch SELECT
	LCD_display_string <= (
-- Line 1
		X"0" & Hex_Display_Data(11 DOWNTO 8),X"0" & Hex_Display_Data(7 DOWNTO 4),X"0" & Hex_Display_Data(3 DOWNTO 0),X"20",X"49",X"4E",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
-- Line 2
		ldd(lds(15)),ldd(lds(14)),ldd(lds(13)),ldd(lds(12)),ldd(lds(11)),ldd(lds(10)),ldd(lds(9)),ldd(lds(8)),
		ldd(lds(7)),ldd(lds(6)),ldd(lds(5)),ldd(lds(4)),ldd(lds(3)),ldd(lds(2)),ldd(lds(1)),ldd(lds(0))) WHEN '1',

	(
-- Line 1
		X"0" & Hex_Display_Data(11 DOWNTO 8),X"0" & Hex_Display_Data(7 DOWNTO 4),X"0" & Hex_Display_Data(3 DOWNTO 0),X"20",X"43",X"4D",X"20",X"20",
		X"20",X"20",X"20",X"20",X"20",X"20",X"20",X"20",
-- Line 2
		ldd(lds(15)),ldd(lds(14)),ldd(lds(13)),ldd(lds(12)),ldd(lds(11)),ldd(lds(10)),ldd(lds(9)),ldd(lds(8)),
		ldd(lds(7)),ldd(lds(6)),ldd(lds(5)),ldd(lds(4)),ldd(lds(3)),ldd(lds(2)),ldd(lds(1)),ldd(lds(0))) WHEN '0';
		
-- BIDIRECTIONAL TRI STATE LCD DATA BUS
   LCD_DATA <= LCD_DATA_VALUE WHEN LCD_RW_INT = '0' ELSE "ZZZZZZZZ";

-- get next character in display string
   Next_Char <= LCD_display_string(CONV_INTEGER(CHAR_COUNT));
   LCD_RW <= LCD_RW_INT;
   
   PROCESS
   BEGIN
    WAIT UNTIL CLOCK_50'EVENT AND CLOCK_50 = '1';
      IF RESET = '0' THEN
       CLK_COUNT_400HZ <= X"00000";
       CLK_400HZ_Enable <= '0';
      ELSE
            IF CLK_COUNT_400HZ < X"0F424" THEN 
             CLK_COUNT_400HZ <= CLK_COUNT_400HZ + 1;
             CLK_400HZ_Enable <= '0';
            ELSE
             CLK_COUNT_400HZ <= X"00000";
             CLK_400HZ_Enable <= '1';
            END IF;
      END IF;
   END PROCESS;

   PROCESS (CLOCK_50, reset)
   BEGIN
      IF reset = '0' THEN
         state <= RESET1;
         LCD_DATA_VALUE <= X"38";
         next_command <= RESET2;
         LCD_EN <= '1';
         LCD_RS <= '0';
         LCD_RW_INT <= '0';

      ELSIF CLOCK_50'EVENT AND CLOCK_50 = '1' THEN
-- State Machine to send commands and data to LCD DISPLAY         
        IF CLK_400HZ_Enable = '1' THEN
         CASE state IS
-- Set Function to 8-bit transfer and 2 line display with 5x8 Font size
-- see Hitachi HD44780 family data sheet for LCD command and timing details
            WHEN RESET1 =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"38";
                  state <= DROP_LCD_EN;
                  next_command <= RESET2;
                  CHAR_COUNT <= "00000";
            WHEN RESET2 =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"38";
                  state <= DROP_LCD_EN;
                  next_command <= RESET3;
            WHEN RESET3 =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"38";
                  state <= DROP_LCD_EN;
                  next_command <= FUNC_SET;
-- EXTRA STATES ABOVE ARE NEEDED FOR RELIABLE PUSHBUTTON RESET OF LCD
            WHEN FUNC_SET =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"38";
                  state <= DROP_LCD_EN;
                  next_command <= DISPLAY_OFF;
-- Turn off Display and Turn off cursor
            WHEN DISPLAY_OFF =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"08";
                  state <= DROP_LCD_EN;
                  next_command <= DISPLAY_CLEAR;
-- Clear Display and Turn off cursor
            WHEN DISPLAY_CLEAR =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"01";
                  state <= DROP_LCD_EN;
                  next_command <= DISPLAY_ON;
-- Turn on Display and Turn off cursor
            WHEN DISPLAY_ON =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"0C";
                  state <= DROP_LCD_EN;
                  next_command <= MODE_SET;
-- Set write mode to auto increment address and move cursor to the right
            WHEN MODE_SET =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"06";
                  state <= DROP_LCD_EN;
                  next_command <= Print_String;
-- Write ASCII hex character in first LCD character location
            WHEN Print_String =>
                  state <= DROP_LCD_EN;
                  LCD_EN <= '1';
                  LCD_RS <= '1';
                  LCD_RW_INT <= '0';
-- ASCII character to output
                  IF Next_Char(7 DOWNTO  4) /= X"0" THEN
                  LCD_DATA_VALUE <= Next_Char;
                  ELSE
-- Convert 4-bit value to an ASCII hex digit
                     IF Next_Char(3 DOWNTO 0) >9 THEN
-- ASCII A...F
                      LCD_DATA_VALUE <= X"4" & (Next_Char(3 DOWNTO 0)-9);
                     ELSE
-- ASCII 0...9
                      LCD_DATA_VALUE <= X"3" & Next_Char(3 DOWNTO 0);
                     END IF;
                  END IF;
                  state <= DROP_LCD_EN;
-- Loop to send out 32 characters to LCD Display  (16 by 2 lines)
                  IF (CHAR_COUNT < 31) AND (Next_Char /= X"FE") THEN 
                   CHAR_COUNT <= CHAR_COUNT +1;
                  ELSE 
                   CHAR_COUNT <= "00000"; 
                  END IF;
-- Jump to second line?
                  IF CHAR_COUNT = 15 THEN next_command <= line2;
-- Return to first line?
                  ELSIF (CHAR_COUNT = 31) OR (Next_Char = X"FE") THEN 
                   next_command <= return_home; 
                  ELSE next_command <= Print_String; END IF;
-- Set write address to line 2 character 1
            WHEN LINE2 =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"C0";
                  state <= DROP_LCD_EN;
                  next_command <= Print_String;
-- Return write address to first character postion on line 1
            WHEN RETURN_HOME =>
                  LCD_EN <= '1';
                  LCD_RS <= '0';
                  LCD_RW_INT <= '0';
                  LCD_DATA_VALUE <= X"80";
                  state <= DROP_LCD_EN;
                  next_command <= Print_String;
-- The next three states occur at the end of each command or data transfer to the LCD
-- Drop LCD E line - falling edge loads inst/data to LCD controller
            WHEN DROP_LCD_EN =>
                  LCD_EN <= '0';
                  state <= HOLD;
-- Hold LCD inst/data valid after falling edge of E line          
            WHEN HOLD =>
                  state <= next_command;
         END CASE;
        END IF;
      END IF;
   END PROCESS;
END Behavior;