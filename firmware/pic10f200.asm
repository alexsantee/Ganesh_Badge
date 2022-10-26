#include "p10f200.inc"

; CONFIG
; __config 0xFEB
 __CONFIG _WDTE_OFF & _CP_OFF & _MCLRE_OFF; disable whatchdog and set GP3 as IO

RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

UART_FLAG_1
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'U'
 retlw 'A'
 retlw 'R'
 retlw 'T'
 retlw '}' 

LED_FLAG_1
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'L'
 retlw 'E'
 retlw 'D'
 retlw '}' 
 
RX_FLAG
 addwf PCL, F
 retlw 'G'
 retlw '{'
 retlw 'R'
 retlw 'X'
 retlw '}' 
 
; Notes:
    
; Call instruction dest are 8 bit only, subroutines must be at first 256 addr
; Hardware stack depth is two (be careful!!!)

; Instruction time is four clock cycles of 4 MHz, so instrucion time is 1us
; Timer counts instruction clock (1MHz)
; For 9600 baud rate, bit time is 104,1 us (should I transmit faster?)
; I think 0.5s is a good period to blink the LED
; but even with the prescaler its bigger than 8-bit TMR0 can handle

; General purpose registers are from 10h-1fh (16 registers) or 8h-1fh at f202

MAIN_PROG CODE                      ; let linker place main program

; Registers:
TMR0 EQU 01h
PCL EQU 02h; Program Counter low bits
 
STATUS EQU 03h
CARRY EQU 0; Carry is status bit 0
ZERO  EQU 2; Zero is status bit 2
  
GPIO EQU 06h
TX  EQU 0
LED EQU 2

; Variables:
PRINT_BUF EQU 10h
BIT_POS EQU 11h
UART_TIME_COUNTER EQU 12h
UART_IDX EQU 13h
LED_TIME_COUNTER EQU 14h
LED_IDX EQU 15h
LED_BIT EQU 16h
FLAGS EQU 17h
BUTTON_F EQU 0; BUTTON is bit 0 of flags
RX_F     EQU 1; RX is bit 1 of flags
LEVEL EQU 18h

; Sends byte from PRINT_BUF through UART interface
UART_SEND
 
 ; sets line from high to low for start bit
 bcf GPIO, TX
 
 ; wait 104 us (9600 baud rate time)
 movlw d'32' ; 104 divided by 3 because dec is 1 cycle and goto is 2
 movwf UART_TIME_COUNTER
 decfsz UART_TIME_COUNTER, F
 GOTO $-1
 
 ; sends the data through TX
 GOTO PRINT_W
UART_SEND_RET
 
 ; sets line from low to high for end bit
 bsf GPIO, TX
 
 ; wait 104 us (9600 baud rate time)
 movlw d'32' ; 104 divided by 3 because dec is 1 cycle and goto is 2
 movwf UART_TIME_COUNTER
 decfsz UART_TIME_COUNTER, F
 GOTO $-1
 
 retlw 0

START
 ; OSSCAL register (calibration) is erased when flash is erased
 
 ; Starts with LED and TX high
 movlw b'11111111'
 movwf GPIO
 ; TRIS = 0b 1111 1010; Set GP0 and GP2 (tx and led) as outputs
 movlw b'11111010'
 tris 6
 ; OPTION = 0b 1101 0100 ; Set timer to internal clock, prescaler is 1:32
 movlw b'11010100'
 option
 
 ; For each main loop the MCU:
 ; 1. Updates LED state
 ; 2. Sends Message through TX
 ; 3. Keeps checking for button press, RX and timer
 ; 4. Reacts to button press or RX
 
 ; LED initialization
 clrf LED_IDX
 clrf LED_BIT
 incf LED_BIT, f
 
MAIN_LOOP
 ; 1. Updates LED state
 
 ; gets current bit
 movfw LED_IDX
 call LED_FLAG_1
 andwf LED_BIT, W
 
 ; sends to GPIO
 btfsc STATUS, ZERO; skips if selected bit was a 1
 bcf GPIO, LED; sets LED to off
 btfss STATUS, ZERO; skips if selected bit was a 0
 bsf GPIO, LED; sets LED to on
 
 ; shifts bit position
 bcf STATUS, CARRY
 ; it would be nice to change this to big endian--------------------------------
 rlf LED_BIT, F
 btfss STATUS, CARRY
 goto END_LED
 ; if was the last bit, resets bit and increments char position
 incf LED_BIT, f
 ; if at an '}' resets index, else incremets it
 movfw LED_IDX
 call LED_FLAG_1
 xorlw '}'
 btfsc STATUS, ZERO
 goto RESET_LED_IDX
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
  movfw UART_IDX; gets current index
  call UART_FLAG_1; gets char at LUT
  movwf PRINT_BUF; puts char in print input
  call UART_SEND; calls print function
  incf UART_IDX, f; increments index
  movfw PRINT_BUF; compares current char with '}' for end condition
  xorlw '}'
  btfss STATUS, ZERO; if last char was '}' exits loop
  goto TX_LOOP
 
 ; 3. Keeps checking for button press, RX and timer
 
 movlw d'61'; Waits for multiple timer overflow to sleep for 0.5s
 movwf LED_TIME_COUNTER
SPOOLING
 ; button press spool
 movlw b'00000100'; GP3 = Button
 andwf GPIO,w
 btfss STATUS, ZERO
 bsf FLAGS, BUTTON_F
 ; rx spool
 movlw b'00000010'; GP1 = RX
 andwf GPIO,w 
 btfss STATUS, ZERO
 bsf FLAGS, RX_F
 ; time overflow spool
 movfw TMR0
 btfss STATUS, ZERO
 goto SPOOLING
 decfsz LED_TIME_COUNTER, f
 goto SPOOLING
 
 ; 4. Reacts to button press or RX
 
 ; button reaction
 ; I must still make the level change code!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 btfss FLAGS, BUTTON_F
 goto END_BUTTON
 incf LEVEL, f
 movlw d'3'; there will be 3 levels?
 xorwf LEVEL,w
 btfsc STATUS, ZERO
 clrf LEVEL
 
END_BUTTON
 
 ; rx reaction
 btfss FLAGS, BUTTON_F
 goto END_RX
 
 ; I may save a lot of space putting this on 2. section!!!!!!!!!!!!!!!!!!!!!!!!!
 clrf UART_IDX; Sets index to zero for first char
LOOP_TX
  movfw UART_IDX; gets current index
  call UART_FLAG_1; gets char at LUT
  movwf PRINT_BUF; puts char in print input
  call UART_SEND; calls print function
  incf UART_IDX, f; increments index
  movfw PRINT_BUF; compares current char with '}' for end condition
  xorlw '}'
  btfss STATUS, ZERO; if last char was '}' exits loop
  goto LOOP_TX
 
END_RX
 
 clrf FLAGS
 
 GOTO MAIN_LOOP


; Sends byte through serial interface from PRINT_BUF, part of UART_SEND
PRINT_W
 ; starts from byte 0 (UART is little endian!)
 movlw 01h
 movwf BIT_POS
 
PRINT_LOOP
  ; clears carry
  bcf STATUS, CARRY
  ; selects bit
  movfw BIT_POS
  andwf PRINT_BUF, W ; may set ZERO flag
  
  ; sends to GPIO
  btfsc STATUS, ZERO; skips if selected bit was a 1
  bcf GPIO, TX; sets TX to 0
  btfss STATUS, ZERO; skips if selected bit was a 0
  bsf GPIO, TX; sets TX to 1
  
  ; wait 104-11 us (9600 baud rate time - instructions time)
  movlw 1;d'31' ; 93 divided by 3 because dec is 1 cycle and goto is 2
  movwf UART_TIME_COUNTER
  decfsz UART_TIME_COUNTER, F
  GOTO $-1
  
  ; increments bit
  rlf BIT_POS, F
  btfss STATUS, CARRY
  GOTO PRINT_LOOP
  
 goto UART_SEND_RET

 END