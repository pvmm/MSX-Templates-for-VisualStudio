;----------------------------------------------------------
;		msxdoscrt0.s - by Danilo Angelo 2020
;		derived from 
;			https://github.com/Konamiman/MSX/blob/master/SRC/SDCC/crt0-msxdos/crt0msx_msxdos.asm
;			https://github.com/Konamiman/MSX/blob/master/SRC/SDCC/crt0-msxdos/crt0msx_msxdos_advanced.asm
;		
;
;		Template for COM programs for MSX-DOS
;----------------------------------------------------------

;--- crt0.asm for MSX-DOS - by Konamiman, 11/2004
	;    Advanced version: allows "int main(char** argv, int argc)",
	;    the returned value will be passed to _TERM on DOS 2,
	;    argv is always 0x100 (the startup code memory is recycled).
	;
    ;    Compile programs with --code-loc 0x180 --data-loc X
    ;    X=0  -> global vars will be placed immediately after code
    ;    X!=0 -> global vars will be placed at address X
    ;            (make sure that X>0x100+code size)

	.include "targetconfig.s"
	.include "memorymap.s"

	.globl	_main

.if GLOBALS_INITIALIZER
	.globl  l__INITIALIZER
    .globl  s__INITIALIZED
    .globl  s__INITIALIZER
.endif

.if PARAM_HANDLING_ROUTINE
phrAddr	.equ paramHandlingRoutine
.else
phrAddr	.equ _HEAP_start
.endif

	.area _HEADER (ABS)
	.org    0x0100  ;MSX-DOS .COM programs start address

;----------------------------------------------------------
;	Step 1: Initialize globals
init:
	call    gsinit

;----------------------------------------------------------
;	Step 2: Build the parameter pointers table on 0x100,
;    and terminate each parameter with 0.
;    MSX-DOS places the command line length at 0x80 (one byte),
;    and the command line itself at 0x81 (up to 127 characters).
.if CMDLINE_PARAMETERS
    ;* Check if there are any parameters at all
    ld      a,(#0x80)
    or      a
    ld      c,#0
    jr      z,cont
        
    ;* Terminate command line with 0
    ;  (DOS 2 does this automatically but DOS 1 does not)
    ld      hl, #0x81
    ld      bc, (#0x80)
    ld      b, #0
    add     hl, bc
    ld      (hl), #0
        
    ;* Copy the command line processing code to other RAM area
	;  (may be HEAP or somewhere else set in 
	;   MemoryMap.Txt|PARAM_HANDLING_ROUTINE item) and
    ;  and execute it from there, this way the memory of the original
    ;  code can be recycled for the parameter pointers table.
    ;  (The space from 0x100 up to "cont" can be used,
    ;   this is room for about 40 parameters.
    ;   No real world application will handle so many parameters.)
    ld      hl, #parloop
    ld      de, #phrAddr
    ld      bc, #parloopend-#parloop
    ldir
        
    ;* Initialize registers and jump to the loop routine    
    ld      hl, #0x81        ;Command line pointer
    ld      c, #0            ;Number of params found
    ld      ix, #0x100       ;Params table pointer
        
    ld      de, #cont        ;To continue execution at "cont"
    push    de               ;when the routine RETs
    jp      phrAddr
        
    ;>>> Command line processing routine begin
        
    ;* Loop over the command line: skip spaces
parloop:
	ld      a,(hl)
    or      a       ;Command line end found?
    ret     z

    cp      #32
    jr      nz,parfnd
    inc     hl
    jr      parloop

    ;* Parameter found: add its address to params table...

parfnd:
	ld      (ix),l
    ld      1(ix),h
    inc     ix
    inc     ix
    inc     c
        
    ld      a,c     ;protection against too many parameters
    cp      #40
    ret     nc
        
    ;* ...and skip chars until finding a space or command line end
        
parloop2:
	ld      a,(hl)
    or      a       ;Command line end found?
    ret     z
        
    cp      #32
    jr      nz,nospc        ;If space found, set it to 0
                            ;(string terminator)...
    ld      (hl),#0
    inc     hl
    jr      parloop         ;...and return to space skipping loop

nospc:
	inc     hl
    jr      parloop2

parloopend:
    ;>>> Command line processing routine end
    ;* Command line processing done. Here, C=number of parameters.

cont:
	ld      hl,#0x100
    ld      b,#0
    push    bc      ;Pass info as parameters to "main"
    push    hl
.endif

;----------------------------------------------------------
;	Step 4: Call the "main" function
	call    _main

;----------------------------------------------------------
;	Step 5: Program termination.
;	Termination code for DOS 2 was returned on L.         
    ld      c,#0x62		; DOS 2 function for program termination (_TERM)
    ld      b,l
    call    5			; On DOS 2 this terminates; on DOS 1 this returns...
    ld      c,#0x0
    jp      5			;...and then this one terminates
						;(DOS 1 function for program termination).

    ;--- Program code and data (global vars) start here

	;* Place data after program code, and data init code after data

		.area	_CODE
		.area	_INITIALIZER

		.area	_DATA
_heap_top::
	.dw _HEAP_start

		.area _INITIALIZED

        .area   _GSINIT
gsinit::
.if GLOBALS_INITIALIZER
        ld	bc,#l__INITIALIZER
        ld	a,b
        or	a,c
        jp	z,gsinext
        ld	de,#s__INITIALIZED
        ld	hl,#s__INITIALIZER
        ldir
.endif

gsinext:
        .area   _GSFINAL
        ret

		.area	_HEAP
_HEAP_start::