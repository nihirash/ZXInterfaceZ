		
;                OUTPUT	"INTZ.ROM"

; System variables definitions

		include	"interfacez-sysvars.asm"

;*****************************************
;** Part 1. RESTART ROUTINES AND TABLES **
;*****************************************

;------
; Start
;------
; At switch on, the Z80 chip is in interrupt mode 0.
; This location can also be 'called' to reset the machine.
; Typically with PRINT USR 0.

	ORG	$0000
			       
START:	DI			; disable interrupts.
	LD	DE,$FFFF	; top of possible physical RAM.
	JP	ROM_CHECK	; jump forward to common code at START_NEW.


	ORG	$0008
		      
RST8:	JP 	RST8


	ORG	$0066
NMIH:	RETN

	ORG 	$0080
	
ROM_CHECK:
	LD	A,$07		; select a white border
	OUT	($FE),A		; and set it now.
	LD	A,$3F		; load accumulator with last page in ROM.
	LD	I,A		; set the I register - this remains constant
				; and can't be in range $40 - $7F as 'snow'
				; appears on the screen.
RAM_CHECK:	
	LD	H,D		; transfer the top value to
	LD	L,E		; the HL register pair.
					;;;$11DC
RAM_FILL:
	LD	(HL),$02	; load with 2 - red ink on black paper
	DEC	HL		; next lower
	CP	H		; have we reached ROM - $3F ?
	JR	NZ,RAM_FILL	; back to RAM_FILL if not.
RAM_READ:	
	AND	A		; clear carry - prepare to subtract
	SBC	HL,DE		; subtract and add back setting
	ADD	HL,DE		; carry when back at start.
	INC	HL		; and increment for next iteration.
	JR	NC,RAM_DONE	; forward to RAM_DONE if we've got back to
				; starting point with no errors.
	DEC	(HL)		; decrement to 1.
	JR	Z,RAM_DONE	; forward to RAM_DONE if faulty.

	DEC	(HL)		; decrement to zero.
	JR	Z,RAM_READ	; back to RAM_READ if zero flag was set.

RAM_DONE:
	DEC	HL
        DEC	HL
        LD	SP, HL
        
        LD	HL, $4000
        LD	D, $BF
        LD	B, $FF

        CALL 	SETATTRS

        LD	DE, SCREEN
        LD 	C, 8
LLOOP1:
        LD	B, 11
WFIFO:  IN	A, ($0B)
        OR	A
        JR 	NZ, WFIFO
        IN	A, ($0D)
        CALL 	PRINTHEX
        INC	DE ; Space
        DJNZ	WFIFO
        DEC 	DE
        DEC	C

        JR	NZ, LLOOP1
        
ENDLESS:
       	JR ENDLESS 



SETATTRS:
        LD	HL, ATTR
        LD	D, $3
        LD	B, $00
        LD	A, $38
ALOOP:
        LD	(HL), A
	INC	HL
        DJNZ	ALOOP
        DEC 	D
        JR 	NZ, ALOOP
        RET

PUTNIBBLE:
        CP	10
        JR	NC, NDEC
	ADD 	A, '0'
        JR	PUTCHAR
NDEC:   ADD	A, 'A'-10
        JR 	PUTCHAR
;
; Print HEX byte in A.
;
; Inputs
; 	DE:	Target screen address

PRINTHEX:
	PUSH 	BC
	LD 	B, A
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        CALL	PUTNIBBLE
        LD	A, B
        AND	$F
        CALL 	PUTNIBBLE
        POP	BC
        RET






;
;      DE: screen address
;	A: char 
PUTCHAR:
	SUB	32
        PUSH 	BC
        PUSH 	DE
        LD	BC, CHAR_SET
        LD	H,$00		; set high byte to 0
	LD	L,A		; character to A
        ADD	HL,HL		; multiply
	ADD	HL,HL		; by
        ADD	HL,HL		; eight
        ADD	HL, BC
        
        LD	B, 8
PCLOOP1:
	LD	A, (HL)
        LD	(DE), A
        INC	D
        INC 	HL
        DJNZ 	PCLOOP1
        POP	DE
        INC 	DE
        POP	BC
        RET















					;;;$3D00
CHAR_SET:	DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
; Character: !
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00000000
; Character: "
		DEFB	%00000000
		DEFB	%00100100
		DEFB	%00100100
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
; Character: #
		DEFB	%00000000
		DEFB	%00100100
		DEFB	%01111110
		DEFB	%00100100
		DEFB	%00100100
		DEFB	%01111110
		DEFB	%00100100
		DEFB	%00000000
; Character: $
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00111110
		DEFB	%00101000
		DEFB	%00111110
		DEFB	%00001010
		DEFB	%00111110
		DEFB	%00001000
; Character: %
		DEFB	%00000000
		DEFB	%01100010
		DEFB	%01100100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00100110
		DEFB	%01000110
		DEFB	%00000000
; Character: &
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00101000
		DEFB	%00010000
		DEFB	%00101010
		DEFB	%01000100
		DEFB	%00111010
		DEFB	%00000000
; Character: '
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
; Character: (
		DEFB	%00000000
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00000100
		DEFB	%00000000
; Character: )
		DEFB	%00000000
		DEFB	%00100000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00100000
		DEFB	%00000000
; Character: *
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010100
		DEFB	%00001000
		DEFB	%00111110
		DEFB	%00001000
		DEFB	%00010100
		DEFB	%00000000
; Character: +
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00111110
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00000000
; Character: ,
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00010000
; Character: -
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111110
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
; Character: .
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00011000
		DEFB	%00011000
		DEFB	%00000000
; Character: /
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000010
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00100000
		DEFB	%00000000
; Character: 0
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000110
		DEFB	%01001010
		DEFB	%01010010
		DEFB	%01100010
		DEFB	%00111100
		DEFB	%00000000
; Character: 1
		DEFB	%00000000
		DEFB	%00011000
		DEFB	%00101000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00111110
		DEFB	%00000000
; Character: 2
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%00000010
		DEFB	%00111100
		DEFB	%01000000
		DEFB	%01111110
		DEFB	%00000000
; Character: 3
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%00001100
		DEFB	%00000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: 4
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00011000
		DEFB	%00101000
		DEFB	%01001000
		DEFB	%01111110
		DEFB	%00001000
		DEFB	%00000000
; Character: 5
		DEFB	%00000000
		DEFB	%01111110
		DEFB	%01000000
		DEFB	%01111100
		DEFB	%00000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: 6
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000000
		DEFB	%01111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: 7
		DEFB	%00000000
		DEFB	%01111110
		DEFB	%00000010
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
; Character: 8
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: 9
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111110
		DEFB	%00000010
		DEFB	%00111100
		DEFB	%00000000
; Character: :
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00000000
; Character: ;
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00100000
; Character: <
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00001000
		DEFB	%00000100
		DEFB	%00000000
; Character: =
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111110
		DEFB	%00000000
		DEFB	%00111110
		DEFB	%00000000
		DEFB	%00000000
; Character: >
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00001000
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00000000
; Character: ?
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00000000
; Character: @
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01001010
		DEFB	%01010110
		DEFB	%01011110
		DEFB	%01000000
		DEFB	%00111100
		DEFB	%00000000
; Character: A
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01111110
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00000000
; Character: B
		DEFB	%00000000
		DEFB	%01111100
		DEFB	%01000010
		DEFB	%01111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01111100
		DEFB	%00000000
; Character: C
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: D
		DEFB	%00000000
		DEFB	%01111000
		DEFB	%01000100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000100
		DEFB	%01111000
		DEFB	%00000000
; Character: E
		DEFB	%00000000
		DEFB	%01111110
		DEFB	%01000000
		DEFB	%01111100
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01111110
		DEFB	%00000000
; Character: F
		DEFB	%00000000
		DEFB	%01111110
		DEFB	%01000000
		DEFB	%01111100
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%00000000
; Character: G
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000000
		DEFB	%01001110
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: H
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01111110
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00000000
; Character: I
		DEFB	%00000000
		DEFB	%00111110
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00111110
		DEFB	%00000000
; Character: J
		DEFB	%00000000
		DEFB	%00000010
		DEFB	%00000010
		DEFB	%00000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: K
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%01001000
		DEFB	%01110000
		DEFB	%01001000
		DEFB	%01000100
		DEFB	%01000010
		DEFB	%00000000
; Character: L
		DEFB	%00000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01111110
		DEFB	%00000000
; Character: M
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01100110
		DEFB	%01011010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00000000
; Character: N
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01100010
		DEFB	%01010010
		DEFB	%01001010
		DEFB	%01000110
		DEFB	%01000010
		DEFB	%00000000
; Character: O
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: P
		DEFB	%00000000
		DEFB	%01111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01111100
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%00000000
; Character: Q
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01010010
		DEFB	%01001010
		DEFB	%00111100
		DEFB	%00000000
; Character: R
		DEFB	%00000000
		DEFB	%01111100
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01111100
		DEFB	%01000100
		DEFB	%01000010
		DEFB	%00000000
; Character: S
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000000
		DEFB	%00111100
		DEFB	%00000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: T
		DEFB	%00000000
		DEFB	%11111110
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
; Character: U
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00111100
		DEFB	%00000000
; Character: V
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%00100100
		DEFB	%00011000
		DEFB	%00000000
; Character: W
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01000010
		DEFB	%01011010
		DEFB	%00100100
		DEFB	%00000000
; Character: X
		DEFB	%00000000
		DEFB	%01000010
		DEFB	%00100100
		DEFB	%00011000
		DEFB	%00011000
		DEFB	%00100100
		DEFB	%01000010
		DEFB	%00000000
; Character: Y
		DEFB	%00000000
		DEFB	%10000010
		DEFB	%01000100
		DEFB	%00101000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
; Character: Z
		DEFB	%00000000
		DEFB	%01111110
		DEFB	%00000100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00100000
		DEFB	%01111110
		DEFB	%00000000
; Character: [
		DEFB	%00000000
		DEFB	%00001110
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001110
		DEFB	%00000000
; Character: \
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000000
		DEFB	%00100000
		DEFB	%00010000
		DEFB	%00001000
		DEFB	%00000100
		DEFB	%00000000
; Character: ]
		DEFB	%00000000
		DEFB	%01110000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%01110000
		DEFB	%00000000
; Character: ^
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00111000
		DEFB	%01010100
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
; Character: _
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%11111111
; Character: Pound
		DEFB	%00000000
		DEFB	%00011100
		DEFB	%00100010
		DEFB	%01111000
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%01111110
		DEFB	%00000000
; Character: a
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111000
		DEFB	%00000100
		DEFB	%00111100
		DEFB	%01000100
		DEFB	%00111100
		DEFB	%00000000
; Character: b
		DEFB	%00000000
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00111100
		DEFB	%00100010
		DEFB	%00100010
		DEFB	%00111100
		DEFB	%00000000
; Character: c
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00011100
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00011100
		DEFB	%00000000
; Character: d
		DEFB	%00000000
		DEFB	%00000100
		DEFB	%00000100
		DEFB	%00111100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111100
		DEFB	%00000000
; Character: e
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111000
		DEFB	%01000100
		DEFB	%01111000
		DEFB	%01000000
		DEFB	%00111100
		DEFB	%00000000
; Character: f
		DEFB	%00000000
		DEFB	%00001100
		DEFB	%00010000
		DEFB	%00011000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00000000
; Character: g
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111100
		DEFB	%00000100
		DEFB	%00111000
; Character: h
		DEFB	%00000000
		DEFB	%01000000
		DEFB	%01000000
		DEFB	%01111000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00000000
; Character: i
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00000000
		DEFB	%00110000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00111000
		DEFB	%00000000
; Character: j
		DEFB	%00000000
		DEFB	%00000100
		DEFB	%00000000
		DEFB	%00000100
		DEFB	%00000100
		DEFB	%00000100
		DEFB	%00100100
		DEFB	%00011000
; Character: k
		DEFB	%00000000
		DEFB	%00100000
		DEFB	%00101000
		DEFB	%00110000
		DEFB	%00110000
		DEFB	%00101000
		DEFB	%00100100
		DEFB	%00000000
; Character: l
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00001100
		DEFB	%00000000
; Character: m
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01101000
		DEFB	%01010100
		DEFB	%01010100
		DEFB	%01010100
		DEFB	%01010100
		DEFB	%00000000
; Character: n
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01111000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00000000
; Character: o
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111000
		DEFB	%00000000
; Character: p
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01111000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01111000
		DEFB	%01000000
		DEFB	%01000000
; Character: q
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111100
		DEFB	%00000100
		DEFB	%00000110
; Character: r
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00011100
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00100000
		DEFB	%00000000
; Character: s
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00111000
		DEFB	%01000000
		DEFB	%00111000
		DEFB	%00000100
		DEFB	%01111000
		DEFB	%00000000
; Character: t
		DEFB	%00000000
		DEFB	%00010000
		DEFB	%00111000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%00001100
		DEFB	%00000000
; Character: u
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111000
		DEFB	%00000000
; Character: v
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00101000
		DEFB	%00101000
		DEFB	%00010000
		DEFB	%00000000
; Character: w
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%01010100
		DEFB	%01010100
		DEFB	%01010100
		DEFB	%00101000
		DEFB	%00000000
; Character: x
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%00101000
		DEFB	%00010000
		DEFB	%00101000
		DEFB	%01000100
		DEFB	%00000000
; Character: y
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%01000100
		DEFB	%00111100
		DEFB	%00000100
		DEFB	%00111000
; Character: z
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%01111100
		DEFB	%00001000
		DEFB	%00010000
		DEFB	%00100000
		DEFB	%01111100
		DEFB	%00000000
; Character: {
		DEFB	%00000000
		DEFB	%00001110
		DEFB	%00001000
		DEFB	%00110000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001110
		DEFB	%00000000
; Character: |
		DEFB	%00000000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00001000
		DEFB	%00000000
; Character: }
		DEFB	%00000000
		DEFB	%01110000
		DEFB	%00010000
		DEFB	%00001100
		DEFB	%00010000
		DEFB	%00010000
		DEFB	%01110000
		DEFB	%00000000
; Character: ~
		DEFB	%00000000
		DEFB	%00010100
		DEFB	%00101000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
		DEFB	%00000000
; Character: Copyright
		DEFB	%00111100
		DEFB	%01000010
		DEFB	%10011001
		DEFB	%10100001
		DEFB	%10100001
		DEFB	%10011001
		DEFB	%01000010
		DEFB	%00111100