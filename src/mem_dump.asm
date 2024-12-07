; Dump idata memory to UART
; UART baud rate 9600
; UART data bits 8, stop bits 1, parity none
; 
; DUMP_ADDR - start dump address
; DUMP_SIZE - dump bytes count
; 
; Dump memory range as one hex string 
.module memdump

; Dump memory range
.equ DUMP_ADDR,     0xF1
.equ DUMP_SIZE,     7

; Timer2 SFR declaration
; Timer2 used by UART 
.equ AUXR,  0x8E
.equ T2H,   0xD6
.equ T2L,   0xD7


.area HOME (CODE)
.area XSEG (DATA)
.area PSEG (DATA)
.area INTV (ABS)

.org 0x0000
_int_reset:
	ljmp main

.area CSEG (ABS, CODE)
.org 0x0100

main:
    mov SP,     #0x3F           ;init stack

    acall       uart_init       ;init UART1

byte_send$:
    mov R0,     #DUMP_SIZE      ; R0 is a counter
    mov R1,     #DUMP_ADDR      ; store current RAM address to R1 
byte_next$:
    mov A,      @R1             ; store value copy from RAM address to A
    acall       print_hex
    
    inc         R1
    djnz R0,    byte_next$

    mov DPL,    #'\n'
    acall       uart_send_byte

    sjmp        byte_send$

; UART1 init routine
; Parameters list is empty
; Return result is empty
; Used registers - none 
uart_init:
    mov SCON,   #0x50
    mov T2H,    #0xFE
    mov T2L,    #0xDF
    mov AUXR,   #0x15
    
    ret

; Send byte to UART1
; Parameters
;   - Byte DPL byte to send
; Return result is void
; Used registers none 
uart_send_byte:
    mov SBUF,   DPL
wait_send_finished$:    
    jbc TI,     uart_send_finished$
    sjmp        wait_send_finished$
uart_send_finished$:
    ret

; Convert byte to 4-digits hex char representation
; Parameters
;   - Byte A value to covert
; Retrun result in R1-R0 (MSB-LSB)
; Used registers: A value stored to stack and restore
; before return from this routine 
byte_to_chars_repr:
    push        A

    anl A,      #0x0F
    acall       to_hex_char
    mov R0,     A

    pop A
    anl A,      #0xF0
    mov R1,     #0x04
shift_left$:                ;shift 4 bits left     
    rl A
    djnz R1, shift_left$
    acall       to_hex_char
    mov R1,     A

    acall       to_hex_char

    ret

; Convert octet to char in range '0'..'F'
; Parameters
;  - Byte A octet to convert
; Return result to A
; Used register DPL is stored in stack and restore
; before return from this routine 
to_hex_char:
    push DPL
    
    anl A,      #0x0F
    mov DPL,    A
    clr         C
    subb A,     #0x0A
    jc is_digit$
    
    add A,  #0x41
    sjmp to_hex_char_end$ 

is_digit$:
    mov A,      DPL
    add A,      #0x30

to_hex_char_end$:
    pop DPL
    ret   

; Print byte to UART as hex string
; Parameters
;   - Byte A byte to convert to hex string
; Return result is void
; Used registers: DPL, R0, R1 values stored to stack and restore 
; before return from this routine 
print_hex:
; push DPL, R0, R1 to stack
    push        DPL
    mov DPL,    R0
    push        DPL
    mov DPL,    R1
    push        DPL

    ; convert byte to hex string representation
    acall       byte_to_chars_repr ; string representaion is placed in R1..R0 

    ; print high octet char
    mov DPL,    R1               
    acall       uart_send_byte
    ;print low octet char
    mov DPL,    R0               
    acall       uart_send_byte

    ;pop R0, R1 and DPL from stack
    pop         DPL
    mov R1,     DPL
    pop         DPL
    mov R0,     DPL          
    pop         DPL

    ret

