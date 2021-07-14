;
;==================================================================================================
;   MD DISK DRIVER (MEMORY DISK)
;==================================================================================================
;
; MD DEVICE CONFIGURATION
;
;
;       DISK DEVICE TYPE ID	MEDIA ID		ATTRIBUTE
;--------------------------------------------------------------------------------------------------
;	0x00 MEMORY DISK	0x02 RAM DRIVE		%00101000 HD STYLE, NON-REMOVABLE, TYPE-RAM
;	0x00 MEMORY DISK	0x01 ROM DRIVE		%00100000 HD STYLE, NON-REMOVABLE, TYPE-ROM
;	0x00 MEMORY DISK	0x01 ROM DRIVE		%00111000 HD STYLE, NON-REMOVABLE, TYPE-FLASH
;
;MD_DEVCNT	.EQU	2		; NUMBER OF MD DEVICES SUPPORTED
MD_CFGSIZ	.EQU	8		; SIZE OF CFG TBL ENTRIES
;
MD_DEV		.EQU	0		; OFFSET OF DEVICE NUMBER (BYTE)
MD_STAT		.EQU	1		; OFFSET OF STATUS (BYTE)
MD_LBA		.EQU	2		; OFFSET OF LBA (DWORD)
MD_MID		.EQU	6		; OFFSET OF MEDIA ID (BYTE)
MD_ATTRIB	.EQU	7		; OFFSET OF ATTRIBUTE (BYTE)
;
MD_AROM		.EQU	%00100000	; ROM ATTRIBUTE
MD_ARAM		.EQU	%00101000	; RAM ATTRIBUTE
MD_AFSH		.EQU	%00111000	; FLASH ATTRIBUTE
;
MD_FDBG		.EQU	0		; FLASH DEBUG CODE
MD_FVBS		.EQU	1		; FLASH VERBOSE OUTPUT
MD_FVAR		.EQU	1		; FLASH VERIFY AFTER WRITE
;
; DEVICE CONFIG TABLE (RAM DEVICE FIRST TO MAKE IT ALWAYS FIRST DRIVE)
;
MD_CFGTBL:
#IF (MDRAM)
	; DEVICE 0 (RAM)
	.DB	0			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	MID_MDRAM		; DEVICE MEDIA ID
	.DB	MD_ARAM			; DEVICE ATTRIBUTE
#ENDIF
;
#IF (MDROM)
	; DEVICE 1 (ROM)
	.DB	1			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	MID_MDROM		; DEVICE MEDIA ID
	.DB	MD_AROM			; DEVICE ATTRIBUTE
#ENDIF
;
MD_DEVCNT	.EQU	($ - MD_CFGTBL) / MD_CFGSIZ
;
#IF ($ - MD_CFGTBL) != (MD_DEVCNT * MD_CFGSIZ)
	.ECHO	"*** INVALID MD CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
;
;
MD_INIT:
#IF (MDFFENABLE)
	CALL	MD_FINIT		; PROBE FLASH CAPABILITY
#ENDIF

	CALL	NEWLINE			; FORMATTING
	PRTS("MD: UNITS=$")
	LD	A,MD_DEVCNT
	CALL	PRTDECB
;
#IF (MDROM)
	PRTS(" ROMDISK=$")
	LD	HL,ROMSIZE - 128
	CALL	PRTDEC
	PRTS("KB$")
#ENDIF
;
#IF (MDRAM)
	PRTS(" RAMDISK=$")
	LD	HL,RAMSIZE - 256
	CALL	PRTDEC
	PRTS("KB$")
#ENDIF
;
; SETUP THE DIO TABLE ENTRIES
;
#IF (MDROM & MDFFENABLE)
	LD	A,(MD_FFSEN)		; IF FLASH 
	OR	A			; FILESYSTEM 
	JR	NZ,MD_INIT1		; CAPABLE, 
	LD	A,MD_AFSH		; UPDATE ROM DIO
	LD	(MD_CFGTBL + MD_CFGSIZ + MD_ATTRIB),A
MD_INIT1:
#ENDIF
;
	LD	DE,MD_CFGTBL
;
MD_INIT2:
	LD	A,(DE)			; FIRST BYTE OF CONFIG
	CP	$FF			; END OF TABLE?
	JR	NZ,MD_INIT3		; IF NOT END OF TABLE, CONTINUE
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
MD_INIT3:
	LD	BC,MD_FNTBL		; BC IS FUNT TBL
	PUSH	DE			; SAVE CFG PTR
	CALL	DIO_ADDENT		; ADD DIO TBL ENTRY
	POP	DE			; RECOVER CFG PTR
	EX	DE,HL			; CFG PTR TO HL
	LD	BC,MD_CFGSIZ		; ENTRY SIZ TO BC
	ADD	HL,BC			; BUMP TO NEXT ENTRY
	EX	DE,HL			; CFG PTR BACK TO DE
	JR	MD_INIT2		; REPEAT
;
;
;
MD_FNTBL:
	.DW	MD_STATUS
	.DW	MD_RESET
	.DW	MD_SEEK
	.DW	MD_READ
	.DW	MD_WRITE
	.DW	MD_VERIFY
	.DW	MD_FORMAT
	.DW	MD_DEVICE
	.DW	MD_MEDIA
	.DW	MD_DEFMED
	.DW	MD_CAP
	.DW	MD_GEOM
#IF (($ - MD_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID MD FUNCTION TABLE ***\n"
#ENDIF
;
;
;
MD_VERIFY:
MD_FORMAT:
MD_DEFMED:
	CALL	SYSCHK			; INVALID SUB-FUNCTION
	LD	A,ERR_NOTIMPL
	OR	A
	RET
;
;
;
MD_STATUS:
;	XOR	A			; ALWAYS OK
;	RET
;
;
;
MD_RESET:
	XOR	A			; ALWAYS OK
	RET
;
;
;	
MD_CAP:					; ASSUMES THAT UNIT 0 IS RAM, UNIT 1 IS ROM
	LD	A,(IY+MD_DEV)		; GET DEVICE NUMBER
	OR	A			; SET FLAGS
	JR	Z,MD_CAP0		; UNIT 0
	DEC	A			; TRY UNIT 1
	JR	Z,MD_CAP1		; UNIT 1
	CALL	SYSCHK			; INVALID UNIT
	LD	A,ERR_NOUNIT
	OR	A
	RET
MD_CAP0:
	LD	A,(HCB + HCB_RAMBANKS)	; POINT TO RAM BANK COUNT
	LD	B,4			; SET # RESERVED ROM BANKS
	JR	MD_CAP2
MD_CAP1:
	LD	A,(HCB + HCB_ROMBANKS)	; POINT TO ROM BANK COUNT
	LD	B,8			; SET # RESERVED RAM BANKS
MD_CAP2:
	SUB	B			; SUBTRACT OUT RESERVED BANKS
	LD	H,A			; H := # BANKS
	LD	E,64			; # 512 BYTE BLOCKS / BANK
	CALL	MULT8			; HL := TOTAL # 512 BYTE BLOCKS
	LD	DE,0			; NEVER EXCEEDS 64K, ZERO HIGH WORD
	LD	BC,512			; 512 BYTE SECTOR
	XOR	A
	RET
;
;
;
MD_GEOM:
	; RAM/ROM DISKS ALLOW CHS STYLE ACCESS BY EMULATING
	; A DISK DEVICE WITH 1 HEAD AND 16 SECTORS / TRACK.
	CALL	MD_CAP			; HL := CAPACITY IN BLOCKS
	PUSH	BC			; SAVE SECTOR SIZE
	LD	D,1 | $80		; HEADS / CYL := 1 BY DEFINITION, SET LBA CAPABILITY BIT
	LD	E,16			; SECTORS / TRACK := 16 BY DEFINITION
	LD	B,4			; PREPARE TO DIVIDE BY 16
MD_GEOM1:
	SRL	H			; SHIFT H
	RR	L			; SHIFT L
	DJNZ	MD_GEOM1		; DO 4 BITS TO DIVIDE BY 16
	POP	BC			; RECOVER SECTOR SIZE
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
;
;
MD_DEVICE:
	LD	D,DIODEV_MD		; D := DEVICE TYPE - ALL ARE MEMORY DISKS
	LD	E,(IY+MD_DEV)		; GET DEVICE NUMBER
	LD	C,(IY+MD_ATTRIB)	; GET ATTRIBUTE
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,0			; L := 0, NO BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
MD_MEDIA:
	LD	E,(IY+MD_MID)		; GET MEDIA ID
	LD	D,0			; D:0=0 MEANS NO MEDIA CHANGE
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
MD_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+MD_LBA+0),L		; SAVE NEW LBA
	LD	(IY+MD_LBA+1),H		; ...
	LD	(IY+MD_LBA+2),E		; ...
	LD	(IY+MD_LBA+3),D		; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
MD_READ:
	CALL	HB_DSKREAD		; HOOK HBIOS DISK READ SUPERVISOR
;
;	HL  POINTS TO HB_WRKBUF
;
#IF (MDFFENABLE)
	LD	A,(IY+MD_ATTRIB)	; GET ADR OF SECTOR READ FUNC
	LD	BC,MD_RDSECF		; 
	CP	MD_AFSH			; RAM / ROM = MD_RDSEC
	JR	Z,MD_RD1		; FLASH     = MD_RDSECF
#ENDIF
	LD	BC,MD_RDSEC
MD_RD1:
	LD	(MD_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	JR	MD_RW			; CONTINUE TO GENERIC R/W ROUTINE
;
;
;
MD_WRITE:
	CALL	HB_DSKWRITE		; HOOK HBIOS DISK WRITE SUPERVISOR
;
#IF (MDFFENABLE)
	LD	A,(IY+MD_ATTRIB)	; GET ADR OF SECTOR WRITE FUNC
	LD	BC,MD_WRSECF		; 
	CP	MD_AFSH			; RAM / ROM = MD_WRSEC
	JR	Z,MD_WR1		; FLASH     = MD_WRSECF
#ENDIF
	LD	BC,MD_WRSEC
MD_WR1:

	LD	(MD_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	LD	A,(IY+MD_ATTRIB)	; IF THE DEVICES ATTRIBUTE
	CP	MD_AROM			; IS NOT ROM THEN WE CAN
	JR	NZ,MD_RW		; WRITE TO IT
	LD	E,0			; UNIT IS READ ONLY, ZERO SECTORS WRITTEN
	LD	A,ERR_READONLY		; SIGNAL ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
;
;
MD_RW:
	LD	(MD_DSKBUF),HL		; SAVE DISK BUFFER ADDRESS
	LD	A,E			; BLOCK COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR READ/WRITE COUNT
MD_RW1:
	PUSH	BC			; SAVE COUNTERS
;
#IF (DSKYENABLE)
	LD	A,MD_LBA
	CALL	LDHLIYA
	CALL	HB_DSKACT		; SHOW ACTIVITY
#ENDIF
;
	LD	HL,(MD_RWFNADR)		; GET PENDING IO FUNCTION ADDRESS
#IF (MDFFENABLE)
	PUSH	IX
	CALL	JPHL			; ... AND CALL IT
	POP	IX
#ELSE
	CALL	JPHL			; ... AND CALL IT
#ENDIF
	JR	NZ,MD_RW2		; IF ERROR, SKIP INCREMENT
	; INCREMENT LBA
	LD	A,MD_LBA		; LBA OFFSET IN CFG ENTRY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE
	; INCREMENT DMA
	LD	HL,MD_DSKBUF+1		; POINT TO MSB OF BUFFER ADR
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES
	XOR	A			; SIGNAL SUCCESS
MD_RW2:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,MD_RW3		; IF ERROR, BAIL OUT
	INC	C			; BUMP COUNT OF SECTORS READ
	DJNZ	MD_RW1			; LOOP AS NEEDED
MD_RW3:
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(MD_DSKBUF)		; CURRENT DMA TO HL
	OR	A			; SET FLAGS BASED ON RETURN CODE
	RET				; AND RETURN, A HAS RETURN CODE
;
; READ FLASH
;
#IF (MDFFENABLE)
MD_RDSECF:				; CALLED FROM MD_RW
;
	CALL	MD_IOSETUPF		; SETUP SOURCE ADDRESS
;
	PUSH	HL			; IS THE SECTOR
	LD	HL,(MD_LBA4K)		; WE WANT TO
	XOR	A			; READ ALREADY
	SBC	HL,BC			; IN THE 4K
	POP	HL			; BLOCK WE HAVE
	JR	Z,MD_SECM		; IN THE BUFFER?
;
					; DESIRED SECTOR IS NOT IN BUFFER
	LD	(MD_LBA4K),BC		; WE WILL READ IN A NEW 4K SECTOR.
					; SAVE THE 4K LBA FOR FUTURE CHECKS
;
	CALL	MD_CALBAS		; SETUP BANK AND SECTOR
;
	LD	IX,MD_F4KBUF		; SET DESTINATION ADDRESS
	LD	HL,MD_FREAD_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: READ 4K SECTOR
;
MD_SECM:
	LD	A,(IY+MD_LBA+0)		; GET SECTOR WITHIN 4K BLOCK
	AND	%00000111		; AND CALCULATE OFFSET OFFSET
	ADD	A,A
	LD	D,A			; FROM THE START
	LD	E,0
;
	LD	HL,MD_F4KBUF		; POINT TO THE SECTOR WE 
	ADD	HL,DE			; WANT TO COPY
	LD	DE,(MD_DSKBUF)
;
#IF (DMAENABLE & (DMAMODE=DMAMODE_ECB))
	LD	BC,512-1		; COPY ONE 512B SECTOR FROM THE
	CALL	DMALDIR			; 4K SECTOR TO THE DISK BUFFER
#ELSE	
	LD	BC,512			; COPY ONE 512B SECTOR FROM THE
	LDIR				; 4K SECTOR TO THE DISK BUFFER
	XOR	A
#ENDIF
	RET
;
; SETUP DE:HL AS THE SECTOR ADDRESS TO READ OR WRITE
;
; ON EXIT
;  BC    = LBA 4K BLOCK WE ARE ACCESSING
;  DE:HL = MEMORY ADDRESS TO ACCESS IN FLASH
;
MD_IOSETUPF:
	LD	L,(IY+MD_LBA+0)		; HL := LOW WORD OF LBA
	LD	H,(IY+MD_LBA+1)		
	INC	H			; SKIP FIRST 128MB (256 SECTORS)
;
	LD	A,L			; SAVE LBA 4K
	AND	%11111000		; BLOCK WE ARE
	LD	C,A			; GOING TO
	LD	B,H			; ACCESS
;
	LD	D,0			; CONVERT LBA
	LD	E,H			; TO ADDRESS
	LD	H,L			; MULTIPLY BY 512
	LD	L,D			; DE:HL = HLX512
	SLA	H
	RL	E
	RL	D	
;
	RET
;
;======================================================================
; CALCULATE BANK AND ADDRESS DATA FROM MEMORY ADDRESS
;
; ON ENTRY DE:HL CONTAINS 32 BIT MEMORY ADDRESS.
; ON EXIT  B     CONTAINS BANK SELECT BYTE
;          C     CONTAINS HIGH BYTE OF SECTOR ADDRESS
;
; DDDDDDDDEEEEEEEE HHHHHHHHLLLLLLLL
; 3322222222221111 1111110000000000
; 1098765432109876 5432109876543210
; XXXXXXXXXXXXSSSS SSSSXXXXXXXXXXXX < S = SECTOR
; XXXXXXXXXXXXBBBB BXXXXXXXXXXXXXXX < B = BANK
;======================================================================
;
MD_CALBAS:
;
#IF (MD_FDBG==1)
	CALL	PC_SPACE		; DISPLAY SECTOR
	CALL	PRTHEX32		; SECTOR ADDRESS 
	CALL	PC_SPACE		; IN DE:HL
#ENDIF
;
	PUSH	HL
	LD	A,E			; BOTTOM PORTION OF SECTOR
	AND	$0F			; ADDRESS THAT GETS WRITTEN
	RLC	H			; WITH ERASE COMMAND BYTE
	RLA				; A15 GETS DROPPED OFF AND
	LD	B,A			; ADDED TO BANK SELECT
;
	LD	A,H			; TOP SECTION OF SECTOR
	RRA				; ADDRESS THAT GETS WRITTEN
	AND	$70			; TO BANK SELECT PORT
	LD	C,A

	POP	HL
;
	LD	(MD_FBAS),BC		; SAVE BANK AND SECTOR FOR USE IN FLASH ROUTINES
;
#IF (MD_FDBG==1)
	CALL	PRTHEXWORD		; DISPLAY BANK AND
	CALL	PC_SPACE		; SECTOR RESULT
#ENDIF

	RET
;
; WRITE FLASH
;
MD_WRSECF:				; CALLED FROM MD_RW
	CALL	MD_IOSETUPF		; SETUP DESTINATION ADDRESS
;
	PUSH	HL			; IS THE SECTOR
	LD	HL,(MD_LBA4K)		; WE WANT TO
	XOR	A			; WRITE ALREADY
	SBC	HL,BC			; IN THE 4K 
	POP	HL			; BLOCK WE HAVE
	JR	Z,MD_SECM1		; IN THE BUFFER
;
	LD	(MD_LBA4K),BC		; SAVE 4K LBA
;
	CALL	MD_CALBAS		; SETUP BANK AND SECTOR
;
	LD	IX,MD_F4KBUF		; SET DESTINATION ADDRESS
	LD	HL,MD_FREAD_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: READ 4K SECTOR
;
MD_SECM1:				; DESIRED SECTOR IS IN BUFFER
	LD	HL,MD_FERAS_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: ERASE 4K SECTOR
	OR	A
	RET	NZ			; RETURN IF ERROR
	;
	; COPY 512B SECTOR INTO 4K SECTOR
	;
	LD	A,(IY+MD_LBA+0)		; GET SECTOR WITHIN 4K BLOCK
	AND	%00000111		; AND CALCULATE OFFSET OFFSET
	ADD	A,A
	LD	D,A			; FROM THE START
	LD	E,0
;
	LD	HL,MD_F4KBUF		; POINT TO THE SECTOR WE 
	ADD	HL,DE			; WANT TO COPY
	EX	DE,HL
;
	LD	HL,(MD_DSKBUF)
#IF (DMAENABLE & (DMAMODE=DMAMODE_ECB))
	LD	BC,512-1		; COPY ONE 512B SECTOR FROM THE
	CALL	DMALDIR			; THE DISK BUFFER TO 4K SECTOR
	RET	NZ			; EXIT IF DMA COPY ERROR
#ELSE
	LD	BC,512			; COPY ONE 512B SECTOR FROM THE
	LDIR				; THE DISK BUFFER TO 4K SECTOR
#ENDIF
;
	LD	IX,MD_F4KBUF		; SET SOURCE ADDRESS
	LD	HL,MD_FWRIT_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: WRITE 4K SECTOR
;
	XOR	A			; PRESUME SUCCESS STATUS
;
#IF (MD_FVAR==1)
	LD	IX,MD_F4KBUF		; SET SOURCE ADDRESS
	LD	HL,MD_FVERI_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: VERIFY 4K SECTOR
;
	OR	A
	RET	Z			; RETURN IF SUCCESSFUL
;
	LD	IX,MD_F4KBUF		; SET SOURCE ADDRESS		; RETRY
	LD	HL,MD_FWRIT_R		; PUT ROUTINE TO CALL		; WRITE
	CALL	MD_FNCALL		; EXECUTE: WRITE 4K SECTOR	; ONCE
;
	LD	IX,MD_F4KBUF		; SET SOURCE ADDRESS		; VERIFY
	LD	HL,MD_FVERI_R		; PUT ROUTINE TO CALL		; AGAIN
	CALL	MD_FNCALL		; EXECUTE: VERIFY 4K SECTOR
;
	OR	A			; SET FINAL STATUS AFTER RETRY
#ENDIF
;
	RET
;
MD_LBA4K	.DW	$FFFF		; LBA OF CURRENT SECTOR
MD_FBAS		.DW	$FFFF		; BANK AND SECTOR
#ENDIF
;
; READ RAM / ROM 
;
MD_RDSEC:
	CALL	MD_IOSETUP		; SETUP FOR MEMORY COPY
#IF (MDTRACE >= 2)
	LD	(MD_SRC),HL
	LD	(MD_DST),DE
	LD	(MD_LEN),BC
#ENDIF
	PUSH	BC
	LD	C,A			; SOURCE BANK
	LD	B,BID_BIOS		; DESTINATION BANK IS RAM BANK 1 (HBIOS)
#IF (MDTRACE >= 2)
	LD	(MD_SRCBNK),BC
	CALL	MD_PRT
#ENDIF
	LD	A,C			; GET SOURCE BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,B			; GET DESTINATION BANK
	LD	(HB_DSTBNK),A		; SET IT
	POP	BC
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; DO THE INTERBANK COPY
#IF (INTMODE == 1)
	EI
#ENDIF
	XOR	A
	RET
;
; WRITE RAM
;
MD_WRSEC:
	CALL	MD_IOSETUP		; SETUP FOR MEMORY COPY
	EX	DE,HL			; SWAP SRC/DEST FOR WRITE
#IF (MDTRACE >= 2)
	LD	(MD_SRC),HL
	LD	(MD_DST),DE
	LD	(MD_LEN),BC
#ENDIF
	PUSH	BC
	LD	C,BID_BIOS		; SOURCE BANK IS RAM BANK 1 (HBIOS)
	LD	B,A			; DESTINATION BANK
#IF (MDTRACE >= 2)
	LD	(MD_SRCBNK),BC
	CALL	MD_PRT
#ENDIF
	LD	A,C			; GET SOURCE BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,B			; GET DESTINATION BANK
	LD	(HB_DSTBNK),A		; SET IT
	POP	BC
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; DO THE INTERBANK COPY
#IF (INTMODE == 1)
	EI
#ENDIF
	XOR	A
	RET
;
; SETUP FOR MEMORY COPY
;   A=BANK SELECT
;   BC=COPY SIZE
;   DE=DESTINATION
;   HL=SOURCE
;
; ASSUMES A "READ" OPERATION.  HL AND DE CAN BE SWAPPED
; AFTERWARDS TO ACHIEVE A WRITE OPERATION
;
; ON INPUT, WE HAVE LBA ADDRESSING IN HSTLBAHI:HSTLBALO
; BUT WE NEVER HAVE MORE THAN $FFFF BLOCKS IN A RAM/ROM DISK,
; SO THE HIGH WORD (HSTLBAHI) IS IGNORED
;
; EACH RAM/ROM BANK IS 32K BY DEFINITION AND EACH SECTOR IS 512
; BYTES BY DEFINITION.	SO, EACH RAM/ROM BANK CONTAINS 64 SECTORS
; (32,768 / 512 = 64).	THEREFORE, YOU CAN THINK OF LBA AS
; 00000BBB:BBOOOOOO IS WHERE THE 'B' BITS REPRESENT THE BANK NUMBER
; AND THE 'O' BITS REPRESENT THE SECTOR NUMBER WITHIN THE BANK.
;
; TO EXTRACT THE BANK NUMBER, WE CAN LEFT SHIFT TWICE TO GIVE US:
; 000BBBBB:OOOOOOOO.  FROM THIS WE CAN EXTRACT THE MSB
; TO USE AS THE BANK NUMBER.  NOTE THAT THE "RAW" BANK NUMBER MUST THEN
; BE OFFSET TO THE START OF THE ROM/RAM BANKS.
; ALSO NOTE THAT THE HIGH BIT OF THE BANK NUMBER REPRESENTS "RAM" SO THIS
; BIT MUST ALSO BE SET ACCORDING TO THE UNIT BEING ADDRESSED.
;
; TO GET THE BYTE OFFSET, WE THEN RIGHT SHIFT THE LSB BY 1 TO GIVE US:
; 0OOOOOOO AND EXTRACT THE LSB TO REPRESENT THE MSB OF
; THE BYTE OFFSET.  THE LSB OF THE BYTE OFFSET IS ALWAYS 0 SINCE WE ARE
; DEALING WITH 512 BYTE BOUNDARIES.
;
MD_IOSETUP:
	LD	L,(IY+MD_LBA+0)		; HL := LOW WORD OF LBA
	LD	H,(IY+MD_LBA+1)		; ...
	; ALIGN BITS TO EXTRACT BANK NUMBER FROM H
	SLA	L			; LEFT SHIFT ONE BIT
	RL	H			;   FULL WORD
	SLA	L			; LEFT SHIFT ONE BIT
	RL	H			;   FULL WORD
	LD	C,H			; BANK NUMBER FROM H TO C
	; GET BANK NUM TO A AND SET FLAG Z=ROM, NZ=RAM
	LD	A,(IY+MD_DEV)		; DEVICE TO A
	AND	$01			; ISOLATE LOW BIT, SET ZF
	LD	A,C			; BANK VALUE INTO A
	PUSH	AF			; SAVE IT FOR NOW
	; ADJUST L TO HAVE MSB OF OFFSET
	SRL	L			; ADJUST L TO BE MSB OF BYTE OFFSET
	LD	H,L			; MOVE MSB TO H WHERE IT BELONGS
	LD	L,0			;   AND ZERO L SO HL IS NOW BYTE OFFSET
	; LOAD DESTINATION AND COUNT
	LD	DE,(MD_DSKBUF)		; DMA ADDRESS IS DESTINATION
	LD	BC,512			; ALWAYS COPY ONE SECTOR
	; FINISH UP
	POP	AF			; GET BANK AND FLAGS BACK
	JR	Z,MD_IOSETUP2		; DO ROM DRIVE, ELSE FALL THRU FOR RAM DRIVE
;
MD_IOSETUP1:	; ROM
	ADD	A,BID_ROMD0
	RET
;
MD_IOSETUP2:	; RAM
	ADD	A,BID_RAMD0
	RET
;
;
;
#IF (MDTRACE >= 2)
MD_PRT:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
;
	CALL	NEWLINE
;
	LD	DE,MDSTR_PREFIX
	CALL	WRITESTR
;
	CALL	PC_SPACE
	LD	DE,MDSTR_SRC
	CALL	WRITESTR
	LD	A,(MD_SRCBNK)
	CALL	PRTHEXBYTE
	CALL	PC_COLON
	LD	BC,(MD_SRC)
	CALL	PRTHEXWORD
;
	CALL	PC_SPACE
	LD	DE,MDSTR_DST
	CALL	WRITESTR
	LD	A,(MD_DSTBNK)
	CALL	PRTHEXBYTE
	CALL	PC_COLON
	LD	BC,(MD_DST)
	CALL	PRTHEXWORD
;
	CALL	PC_SPACE
	LD	DE,MDSTR_LEN
	CALL	WRITESTR
	LD	BC,(MD_LEN)
	CALL	PRTHEXWORD
;
	POP	HL
	POP	DE
	POP	BC
	POP	AF
;
	RET
;
MDSTR_PREFIX	.TEXT	"MD:$"
MDSTR_SRC	.TEXT	"SRC=$"
MDSTR_DST	.TEXT	"DEST=$"
MDSTR_LEN	.TEXT	"LEN=$"
#ENDIF
;
;==================================================================================================
;   FLASH DRIVERS
;==================================================================================================
;
;	UPPER RAM BANK IS ALWAYS AVAILABLE REGARDLESS OF MEMORY BANK SELECTION. 
;	HBX_BNKSEL AND HB_CURBNK ARE ALWAYS AVAILABLE IN UPPER MEMORY.
;
;	THE STACK IS IN UPPER MEMORY DURING BIOS INITIALIZATION BUT IS IN LOWER
;	MEMORY DURING HBIOS CALLS.
;
;	TO ACCESS THE FLASH CHIP FEATURES, CODE IS COPIED TO THE UPPER RAM BANK (HBX_BUF)
;	AND THE FLASH CHIP IS SWITCHED INTO THE LOWER BANK.
;
;	EACH FLASH ROUTINE MUST FIT INTO TO THE HBX_BUF, INCLUDING IT'S LOCAL STACK WHICH
;	IS REQUIRED FOR CALLING THE BANK SWITCH ROUTINES. 
;
;	INSPIRED BY WILL SOWERBUTTS FLASH4 UTILITY - https://github.com/willsowerbutts/flash4/
;
;	REFERENCE ww1.microchip.com/downloads/en/DeviceDoc/SST39SF040.txt
;
;==================================================================================================
;
#IF (MDFFENABLE)
MD_TGTDEV	.EQU	0B7BFH		; TARGET CHIP FOR R/W FILESYSTEM 39SF040
;
;======================================================================
; BIOS FLASH INITIALIZATION
;
; IDENTIFY AND DISPLAY FLASH CHIPS IN SYSTEM.
; USES MEMORY SIZE DEFINED BY BUILD CONFIGURATION.
;======================================================================
;
MD_FINIT:
	LD	A,+(ROMSIZE/512)	; DISLAY NUMBER
#IF (MD_FVBS==1)
	CALL	NEWLINE			; OF UNITS 
	PRTS("MD: FLASH=$")
	CALL	PRTDECB			; CONFIGURED FOR.
#ENDIF
	LD	B,A			; NUMBER OF DEVICES TO PROBE
	LD	C,$00			; START ADDRESS IS 0000:0000 IN DE:HL
MD_PROBE:
	LD	D,$00			; SET ADDRESS IN DE:HL
	LD	E,C			;
	LD	H,D			; WE INCREASE E BY $08
	LD	L,D			; ON EACH CYCLE THROUGH
;	 
	PUSH	BC
#IF (MD_FVBS==1)
	CALL	PC_SPACE
	LD	A,+(ROMSIZE/512)+1
	SUB	B			; PRINT
	CALL	PRTDECB			; DEVICE 
	LD	A,'='			; NUMBER
	CALL	COUT
#ENDIF
	PUSH	HL
	CALL	MD_CALBAS		; SETUP BANK AND SECTOR
	LD	HL,MD_FIDEN_R		; PUT ROUTINE TO CALL
	CALL	MD_FNCALL		; EXECUTE: IDENTIFY FLASH CHIP

	LD	HL,MD_TGTDEV		; IF WE MATCH WITH
	XOR	A			; A NON 39SF040
	SBC	HL,BC			; CHIP SET THE
	JR	Z,MD_PR2		; R/W FLAG TO R/O
	LD	HL,MD_FFSEN		; A NON ZERO VALUE
	SET	0,(HL)			; MEANS WE CAN'T
					; ENABLE FLASH WRITING
MD_PR2:
	POP	HL
#IF (MD_FVBS==1)
	CALL	MD_LAND			; LOOKUP AND DISPLAY
#ENDIF
	POP	BC
;
	LD	A,C			; UPDATE ADDRESS
	ADD	A,$08			; TO NEXT DEVICE
	LD	C,A
;
	DJNZ	MD_PROBE		; ALWAYS AT LEAST ONE DEVICE

#IF (MD_FVBS==1)
	CALL	PRTSTRD
	.TEXT " FLASH FILE SYSTEM $"
	LD	DE,MD_FFMSGDIS
	LD	A,(MD_FFSEN)
	OR	A
	JR	NZ,MD_PR1
	LD	DE,MD_FFMSGENA
MD_PR1:	CALL	WRITESTR
#ENDIF

	XOR	A			; INIT SUCCEEDED
	RET
;
;======================================================================
; LOOKUP AND DISPLAY CHIP
;
; ON ENTRY BC CONTAINS CHIP ID
; ON EXIT  A  CONTAINS STATUS 0=SUCCESS, NZ=NOT IDENTIFIED
;======================================================================
;
MD_LAND:
;
#IF (MD_FDBG==1)
	PRTS(" ID:$")
	CALL	PRTHEXWORD		; DISPLAY FLASH ID
	CALL	PC_SPACE
#ENDIF
;
	LD	HL,MD_TABLE		; SEARCH THROUGH THE FLASH
	LD	DE,MD_T_CNT		; TABLE TO FIND A MATCH
MD_NXT1:LD	A,(HL)
	CP	B
	JR	NZ,MD_NXT0		; FIRST BYTE DOES NOT MATCH
;
	INC	HL		
	LD	A,(HL)
	CP	C
	DEC	HL
	JR	NZ,MD_NXT0		; SECOND BYTE DOES NOT MATCH
;
	INC	HL
	INC	HL
	JR	FF_NXT2			; MATCH SO EXIT
;
MD_NXT0:PUSH	BC			; WE DIDN'T MATCH SO POINT
	LD	BC,MD_T_SZ		; TO THE NEXT TABLE ENTRY
	ADD	HL,BC
	POP	BC
;
	LD	A,D			; CHECK IF WE REACHED THE
	OR	E			; END OF THE TABLE
	DEC	DE
	JR	NZ,MD_NXT1		; NOT AT END YET
;
	LD	HL,MD_FFMSGUNK		; WE REACHED THE END WITHOUT A MATCH
;
FF_NXT2:
#IF (MD_FVBS==1)
	CALL	PRTSTR			; AFTER SEARCH DISPLAY THE RESULT
#ENDIF
	RET
;
;======================================================================
; COMMON FUNCTION CALL FOR:
;
;  MD_FIDEN_R - IDENTIFY FLASH CHIP	
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;   ON EXIT  BC      CONTAINS THE CHIP ID BYTES.
;            A       NO STATUS IS RETURNED 
;
;  MD_FERAS_R - ERASE FLASH SECTOR	
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;   ON EXIT  A       RETURNS STATUS 0=SUCCESS NZ=FAIL
;
;  MD_FREAD_R - READ FLASH SECTOR    
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO WHERE TO SAVE DATA
;   ON EXIT  A       NO STATUS IS RETURNED
;
;  MD_FVERI_R - VERIFY FLASH SECTOR
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO DATA TO COMPARE.
;   ON EXIT  A       RETURNS STATUS 0=SUCCESS NZ=FAIL
;
;  MD_FWRIT_R - WRITE FLASH SECTOR   
;   ON ENTRY MD_FBAS HAS BEEN SET WITH BANK AND SECTOR BEING ACCESSED
;            HL      POINTS TO THE ROUTINE TO BE RELOCATED AND CALLED
;            IX      POINTS TO DATA TO BE WRITTEN
;   ON EXIT  A       NO STATUS IS RETURNED
;
; GENERAL OPERATION:
;  COPY FLASH CODE TO CODE BUFFER
;  CALL RELOCATED FLASH CODE
;  RETURN WITH ID CODE.
;======================================================================
;
MD_FNCALL:				; USING HBX_BUF FOR CODE AREA
;
	LD	B,0			; RETREIVE THE
	DEC	HL			; CODE SIZE TO
	LD	C,(HL)			; BE COPIED
	INC	HL			; MAXIMUM 64 BYTES
;
	LD	DE,HBX_BUF		; EXECUTE / START ADDRESS
	LDIR				; COPY OUR RELOCATABLE CODE TO THE BUFFER
;
	LD	D,B			; PRESET DE TO ZERO TO REDUCE
	LD	E,B			; CODE SIZE IN RELOCATABLE CODE
;
	LD	BC,(MD_FBAS)		; PUT BANK AND SECTOR DATA IN BC
;
#IF (MD_FDBG==1)
	CALL	PRTHEXWORD
#ENDIF
;
	LD	A,(HB_CURBNK)		; WE ARE STARTING IN HB_CURBNK
;
	HB_DI
	LD	(MD_SAVSTK),SP		; SAVE CURRENT STACK
	LD	SP,HBX_BUF_END		; SETUP A NEW HIMEM STACK AT END OF HX_BUF
	CALL	HBX_BUF			; EXECUTE RELOCATED CODE
	LD	SP,(MD_SAVSTK)		; RESTORE STACK
	HB_EI
;
#IF (MD_FDBG==1)
	CALL	PC_SPACE
	CALL	PRTHEXWORD
	CALL	PC_SPACE
	EX	DE,HL
	CALL	PRTHEXWORDHL
	CALL	PC_SPACE
	EX	DE,HL
#ENDIF
;
	LD	A,C			; RETURN WITH STATUS IN A
	RET				; RETURN TO MD_READF, MD_WRITEF
;
MD_SAVSTK	.DW	0		
;
#INCLUDE "flashlib.inc"
;
;======================================================================
;
; FLASH CHIP LIST
;
;======================================================================
;
#DEFINE	FF_CHIP(FFROMID,FFROMNM)	\
#DEFCONT ;				\
#DEFCONT	.DW	FFROMID		\
#DEFCONT	.DB	FFROMNM		\
#DEFCONT ;
;
MD_TABLE:
FF_CHIP(00120H,"29F010$    ")
FF_CHIP(001A4H,"29F040$    ")
FF_CHIP(01F04H,"AT49F001NT$")
FF_CHIP(01F05H,"AT49F001N$ ")
FF_CHIP(01F07H,"AT49F002N$ ")
FF_CHIP(01F08H,"AT49F002NT$")
FF_CHIP(01F13H,"AT49F040$  ")
FF_CHIP(01F5DH,"AT29C512$  ")
FF_CHIP(01FA4H,"AT29C040$  ")
FF_CHIP(01FD5H,"AT29C010$  ")
FF_CHIP(01FDAH,"AT29C020$  ")
FF_CHIP(02020H,"M29F010$   ")
FF_CHIP(020E2H,"M29F040$   ")
FF_CHIP(0BFB5H,"39F010$    ")
FF_CHIP(0BFB6H,"39F020$    ")
FF_CHIP(0BFB7H,"39F040$    ")
FF_CHIP(0C2A4H,"MX29F040$  ")
;
MD_T_CNT	.EQU	17
MD_T_SZ		.EQU	($-MD_TABLE) / MD_T_CNT
MD_FFMSGUNK	.DB	"UNKNOWN$"
MD_FFMSGDIS	.DB	"DISABLED$"
MD_FFMSGENA	.DB	"ENABLED$"
;
;======================================================================
;
; 4K FLASH SECTOR BUFFER
;
;======================================================================
;
MD_F4KBUF	.FILL	4096,$FF
MD_FFSEN	.DB	00h		; FLASH FILES SYSTEM ENABLE
;
#ENDIF
;
MD_RWFNADR	.DW	0
MD_DSKBUF	.DW	0
MD_SRCBNK	.DB	0
MD_DSTBNK	.DB	0
MD_SRC		.DW	0
MD_DST		.DW	0
MD_LEN		.DW	0
