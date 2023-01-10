; Notes:
    
; Call instruction dest are 8 bit only, subroutines must be at first 256 addr
; Hardware stack depth is two (be careful!!!)

; Instruction time is four clock cycles of 4 MHz, so instrucion time is 1us
; Timer counts instruction clock (1MHz)
; For 9600 baud rate, bit time is 104,1 us (should I transmit faster?)
; I think 0.5s is a good period to blink the LED
; but even with the prescaler its bigger than 8-bit TMR0 can handle

; General purpose registers are from 10h-1fh (16 registers) or 8h-1fh at f202
    
#include "p10f200.inc"

; CONFIG
; __config 0xFEB
 __CONFIG _WDTE_OFF & _CP_OFF & _MCLRE_OFF; disable whatchdog and set GP3 as IO
MAIN_PROG CODE                      ; let linker place main program
 
RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

UART_FLAG_1
 movfw UART_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'U'
 retlw 'A'
 retlw 'R'
 retlw 'T'
 retlw '1'
 retlw '}'

UART_FLAG_2
 movfw UART_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'U'
 retlw 'A'
 retlw 'R'
 retlw 'T'
 retlw '2'
 retlw '}'
 
UART_FLAG_3
 movfw UART_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'U'
 retlw 'A'
 retlw 'R'
 retlw 'T'
 retlw '3'
 retlw '}'
 
LED_FLAG_1
 movfw LED_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'L'
 retlw 'E'
 retlw 'D'
 retlw '1'
 retlw '}' 

LED_FLAG_2
 movfw LED_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'L'
 retlw 'E'
 retlw 'D'
 retlw '2'
 retlw '}' 

LED_FLAG_3
 movfw LED_IDX
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'L'
 retlw 'E'
 retlw 'D'
 retlw '3'
 retlw '}' 
 
RX_FLAG
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'R'
 retlw 'X'
 retlw '}' 
 
; No part of the program reaches this region
; This flag is intended to be obtained through a flash dump
UNREACHABLE_FLAG
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'R'
 retlw 'O'
 retlw 'M'
 retlw 'D'
 retlw 'u'
 retlw 'm'
 retlw 'p'
 retlw '}' 

; This flag is just a comment, for people who found the repository
; G{Spying_G1tHub}
 
; Registers:
TMR0 EQU 01h
PCL EQU 02h; Program Counter low bits
 
STATUS EQU 03h
CARRY EQU 0; Carry is status bit 0
ZERO  EQU 2; Zero is status bit 2
  
GPIO EQU 06h
TX  EQU 0
LED EQU 2

; Constants
LEVEL_NUM EQU d'3'
; UART timings obtained via simulation
START_BIT_TIME EQU d'31'
DATA_BIT_TIME  EQU d'31'
END_BIT_TIME   EQU d'26'
; LED blinking counter, obtained via simulation to ~0.5s
LED_TIME       EQU d'209'
 
; Variables:
PRINT_BUF EQU 10h
UART_TIME_COUNTER EQU 11h
UART_IDX EQU 12h
UART_BIT EQU 13h

LED_TIME_COUNTER EQU 14h
LED_IDX EQU 15h
LED_BIT EQU 16h

FLAGS EQU 17h
BUTTON_F    EQU 0; BUTTON is bit 0 of flags
RX_LAST_F   EQU 1; Last RX state is bit 1 of flags
RX_CHANGE_F EQU 2; RX change is bit 2 of flags

LEVEL EQU 18h
 
; Functions
 
; Flag selection functions (use call)
UART_FLAG_SELECT
 movfw LEVEL
 addwf PCL, F
 GOTO UART_FLAG_1
 GOTO UART_FLAG_2
 GOTO UART_FLAG_3
 
LED_FLAG_SELECT
 movfw LEVEL
 addwf PCL, F
 GOTO LED_FLAG_1
 GOTO LED_FLAG_2
 GOTO LED_FLAG_3
 
; Sends byte from PRINT_BUF through UART interface
UART_SEND
 
 ; sets line from high to low for start bit
 bcf GPIO, TX
 
 ; wait 104 us (9600 baud rate time)
 movlw START_BIT_TIME
 movwf UART_TIME_COUNTER
 decfsz UART_TIME_COUNTER, F
 GOTO $-1
 
 ; sends the data through TX
 GOTO PRINT_W
PRINT_W_RET
 
 ; sets line from low to high for end bit
 bsf GPIO, TX
 
 ; wait 104 us (9600 baud rate time)
 movlw END_BIT_TIME
 movwf UART_TIME_COUNTER
 decfsz UART_TIME_COUNTER, F
 GOTO $-1
 
 retlw 0

 ; Sends byte through serial interface from PRINT_BUF, part of UART_SEND
PRINT_W
 ; starts from byte 0 for shifting UART_BIT (UART is little endian!)
 movlw 01h
 movwf UART_BIT
 
PRINT_LOOP
  ; clears carry
  bcf STATUS, CARRY
  ; selects bit
  movfw UART_BIT
  andwf PRINT_BUF, W ; may set ZERO flag
  
  ; sends to GPIO
  btfsc STATUS, ZERO; skips if selected bit was a 1
  bcf GPIO, TX; sets TX to 0
  btfss STATUS, ZERO; skips if selected bit was a 0
  bsf GPIO, TX; sets TX to 1
  
  ; wait 104-11 us (9600 baud rate time - instructions time)
  movlw DATA_BIT_TIME
  movwf UART_TIME_COUNTER
  decfsz UART_TIME_COUNTER, F
  GOTO $-1
  
  ; increments bit
  rlf UART_BIT, F
  btfss STATUS, CARRY
  GOTO PRINT_LOOP
  
 goto PRINT_W_RET
 
START
 ; clear memory (8h-1fh at f202 and 10h-1fh at f200)
 clrf 8h
 clrf 9h
 clrf 0ah
 clrf 0bh
 clrf 0ch
 clrf 0dh
 clrf 0eh
 clrf 0fh
 clrf 10h
 clrf 11h
 clrf 12h
 clrf 13h
 clrf 14h
 clrf 15h
 clrf 16h
 clrf 17h
 clrf 18h
 clrf 19h
 clrf 1ah
 clrf 1bh
 clrf 1ch
 clrf 1dh
 clrf 1eh
 clrf 1fh
 ; OSSCAL register (calibration) is erased when flash is erased
 
 ; Starts with LED and TX high
 movlw b'11111111'
 movwf GPIO
 ; TRIS = 0b 1111 1010; Set GP0 and GP2 (tx and led) as outputs
 movlw b'11111010'
 tris 6
 ; OPTION = 0b 1101 0100 ; Set timer to internal clock, prescaler is 1:32
 ; bits are:
 ; 7   - *GPWU (wake up on change)
 ; 6   - *GPPU (internal pull ups)
 ; 5   - T0CS (timer source 1=IO pin, 0=internal oscilator)
 ; 4   - T0SE (edge select 1=fall 0=rise)
 ; 3   - PSA (prescaler assignment 1=watchdog 0=timer0)
 ; 2-0 - prescaler rate
 movlw b'11010100'
 option
 
 ; LED initialization
 bsf LED_BIT, 7; starts at MSB for big endianess
 
 ; For each main loop the MCU:
 ; 1. Updates LED state
 ; 2. Sends Message through TX
 ; 3. Keeps checking for button press, RX and timer
 ; 4. Reacts to button press or RX
 
MAIN_LOOP
 ; 1. Updates LED state
 
 ; gets current bit
 call LED_FLAG_SELECT
 andwf LED_BIT, W
 
 ; sends to GPIO
 btfsc STATUS, ZERO; skips if selected bit was a 1
 bcf GPIO, LED; sets LED to off
 btfss STATUS, ZERO; skips if selected bit was a 0
 bsf GPIO, LED; sets LED to on
 
 ; shifts bit position
 bcf STATUS, CARRY
 rrf LED_BIT, F
 btfss STATUS, CARRY
 goto END_LED
 ; if was the last bit, resets bit and increments char position
 bsf LED_BIT, 7
 ; if at an '}' resets index, else incremets it
 call LED_FLAG_SELECT
 xorlw '}'
 btfss STATUS, ZERO
 goto INCR_LED_IDX
RESET_LED_IDX
 clrf LED_IDX
 goto END_LED
INCR_LED_IDX
 incf LED_IDX, f
 
END_LED
 
 ; 2. Sends Message through TX
 clrf UART_IDX; Sets index to zero for first char
TX_LOOP
  call UART_FLAG_SELECT; gets char at LUT
  movwf PRINT_BUF; puts char in print input
  call UART_SEND; calls print function
  incf UART_IDX, f; increments index
  movfw PRINT_BUF; compares current char with '}' for end condition
  xorlw '}'
  btfss STATUS, ZERO; if last char was '}' exits loop
  goto TX_LOOP
 
 ; 3. Keeps checking for button press, RX and timer
 
 movlw LED_TIME ; constant for time counting
 movwf LED_TIME_COUNTER
SPOOLING
 ; button press spool
 movlw b'00001000'; GP3 = Button
 andwf GPIO,w
 btfsc STATUS, ZERO
 bsf FLAGS, BUTTON_F
 ; rx spool
 movlw b'00000010'; GP1 = RX
 andwf GPIO,w 
 btfss STATUS, ZERO
 goto RX_HIGH
RX_LOW
 btfsc FLAGS, RX_LAST_F
 bsf FLAGS, RX_CHANGE_F
 bcf FLAGS, RX_LAST_F
 goto END_RX_CHANGE
RX_HIGH
 btfss FLAGS, RX_LAST_F
 bsf FLAGS, RX_CHANGE_F
 bsf FLAGS, RX_LAST_F
END_RX_CHANGE
 ; timer overflow spool
 movfw TMR0
 btfsc STATUS, ZERO
 decfsz LED_TIME_COUNTER, f
 goto SPOOLING
 
 ; 4. Reacts to button press or RX
 
 ; button reaction
 btfss FLAGS, BUTTON_F
 goto END_BUTTON
 
 ; Resets led counter
 clrf LED_IDX
 clrf LED_BIT
 bsf  LED_BIT, 7
 
 ; Increments level
 incf LEVEL, f
 movlw LEVEL_NUM
 xorwf LEVEL,w
 btfsc STATUS, ZERO
 goto RESET_LEVEL
 goto END_BUTTON
RESET_LEVEL
 clrf LEVEL
 
END_BUTTON
 
 ; rx reaction
 btfss FLAGS, RX_CHANGE_F
 goto END_RX
 
 clrf UART_IDX; Sets index to zero for first char
LOOP_TX
  movfw UART_IDX; gets current index
  call RX_FLAG; gets char at LUT
  movwf PRINT_BUF; puts char in print input
  call UART_SEND; calls print function
  incf UART_IDX, f; increments index
  movfw PRINT_BUF; compares current char with '}' for end condition
  xorlw '}'
  btfss STATUS, ZERO; if last char was '}' exits loop
  goto LOOP_TX
 
END_RX
 
 bcf FLAGS, BUTTON_F
 bcf FLAGS, RX_CHANGE_F
 
 GOTO MAIN_LOOP

 END