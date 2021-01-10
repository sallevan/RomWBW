;*****************************************************************************
; ROMWBW XMODEM FLASH UPDATER
;
; PROVIDES THE CAPABILTY TO UPDATE ROMWBW FROM THE SBC BOOT LOADER USING
; AN XMODEM FILE TRANSFER. FOR SYSTEMS WITH AN SST39SF040 FLASH CHIP.
;
; TO INSTALL, SAVE THIS FILE AS USRROM.ASM IN \RomWBW\Source\HBIOS
; AND REBUILD AND INSTALL THE NEW ROM VERSION.
;
; THE UPDATER CAN THEN BE ACCESSED USING THE "U" OPTION IN THE SBC BOOT LOADER.
;
; OPTION (C) AND (S) - CONSOLE AND SERIAL DEVICE
;
;  BY DEFAULT THE UPDATER IS SET TO USE THE FIRST ROMWBW CONSOLE DEVICE (0) FOR
;  DISPLAY OUTPUT AND FILES TRANSFER. IF YOU USE A DIFFERENT SERIAL DEVICE FOR
;  THE FILE TRANSFER, PROGRESS INFORMATION WILL BE DISPLAYED.
;
; OPTION (V) - WRITE VERIFY
;
;  BY DEFAULT EACH FLASH SECTOR WILL BE VERIFIED AFTER BEING WRITTEN. SLIGHT
;  PERFORMANCE IMPROVEMENTS CAN BE GAINED IF TURNED OFF AND COULD BE USED IF
;  YOU ARE EXPERIENCING RELIABLE TRANSFERS AND FLASHING.
;
; OPTION (R) - REBOOT
;  EXECUTE A COLD REBOOT. THIS SHOULD BE DONE AFTER A SUCCESSFUL UPDATE. IF
;  YOU PERFORM A COLD REBOOT AFTER A FAILED UPDATE THEN IT IS LIKELY THAT
;  YOUR SYSTEM WILL BE UNUSABLE AND REMOVING AND REPROGRAMMING THE FLASH
;  WILL BE REQUIRED.
;
; OPTION (U) - BEGIN UPDATE
;  WILL BEGIN THE UPDATE PROCESS. THE UPDATER WILL EXPECT TO START RECEIVING
;  AN XMODEM FILE ON THE SERIAL DEVICE UNIT.
;
;   XMODEM SENDS THE FILE IN PACKETS OF 128 BYTES. THE UPDATER WILL CACHE 32
;   PACKETS WHICH IS 1 FLASH SECTOR AND THEN WRITE THAT SECTOR TO THE
;   FLASH DEVICE.
;
;   IF USING SEPARATE CONSOLE, BANK AND SECTOR PROGESS INFORMATION WILL SHOWN
;
;    BANK 00 S00 S01 S02 S03 S04 S05 S06 S06 S07
;    BANK 01 S00 S01 S02 S03 S04 S05 S06 S06 S07
;    BANK 02 S00 S01 S02 S03 S04 S05 S06 S06 S07 etc
;
;   THE XMODEM FILE TRANSFER PROTOCOL DOES NOT PROVIDE ANY FILENAME OR SIZE
;   INFORMATION FOR THE TRANSFER SO THE UPDATER DOES NOT PERFORM ANY CHECKS
;   ON THE FILE SUITABILITY.
;
;   THE UPDATER EXPECTS THE FILE SIZE TO BE A MULTIPLE OF 4 KILOBYTES AND
;   WILL WRITE ALL DATA RECEIVED TO THE FLASH DEVICE. A SYSTEM UPDATE
;   FILE (128KB .IMG) OR COMPLETE ROM CAN BE RECEIVED AND WRITTEN (512KB OR
;   1024KB .ROM)
;
;   IF THE UPDATE FAILS IT IS RECOMMENDED THAT YOU RETRY BEFORE REBOOTING OR
;   EXITING TO THE SBC BOOT LOADER AS YOUR MACHINE MAY NOT BE BOOTABLE.
;
; OPTION (X) - EXIT TO THE SBC BOOT LOADER. THE SBC IS RELOADED FROM ROM AND
;  EXECUTED. AFTER A SUCCESSFUL UPDATE A REBOOT SHOULD BE PERFORMED. HOWEVER,
;  IN THE CASE OF A FAILED UPDATE THIS OPTION COULD BE USED TO ATTEMPT TO
;  LOAD CP/M AND PERFORM THE NORMAL XMODEM / FLASH PROCESS TO RECOVER.
;
; OPTION (D) - DUPLICATE FLASH #1 TO FLASH #2 WILL MAKE A COPY OF FLASH #1 
;  ONTO FLASH #2. THE PURPOSE OF THIS IS TO ENABLE MAKING A BACKUP COPY OF
;  THE CURRENT FLASH. 
;
; OPTION (H) - DEBUG OPTION - SWITCH ON CPU CLOCK DIVIDER ON SBC-V2-004+
; OPTION (T) - DEBUG OPTION - TEST TIMER FOR 20 SECONDS. * = START AND FINISH
;
;
; V.DEV	8/1/2021	PHIL SUMMERS, DIFFICULTYLEVELHIGH@GMAIL.COM
;			b1ackmai1er ON RETROBREWCOMPUTERS.ORG
;
;
; NOTES:
;  TESTED WITH TERATERM XMODEM.
;  ONLY SST39F040 FLASH CHIP IS SUPPORTED DUE TO 4K SECTOR REQUIREMENT.
;  SBC V2-005 MEGAFLASH REQUIRED FOR 1MB FLASH SUPPORT.
;  FAILURE HANDLING HAS NOT BEEN TESTED.
;  TIMING BROADLY CALIBRATED ON A Z80 SBC-V2
;  UNABIOS NOT SUPPORTED
;
; MAXIMUM SERIAL SPEED LIMITATIONS
;
;  SBC-V2 UART NO FLOW CONTROL 2MHZ  | 9600
;  SBC-V2 UART NO FLOW CONTROL 4MHZ  | 19200
;  SBC-V2 UART NO FLOW CONTROL 5MHZ  | 19200
;  SBC-V2 UART NO FLOW CONTROL 8MHZ  | 38400
;  SBC-V2 UART NO FLOW CONTROL 10MHZ | 38400
;  SBC-V2 USB-FIFO 2MHZ+             | N/A
;
; ACKNOWLEDGEMENTS:
;
; XR - Xmodem Receive for Z80 CP/M 2.2 using CON:
; Copyright 2017 Mats Engstrom, SmallRoomLabs
; Licensed under the MIT license
; https://github.com/SmallRoomLabs/xmodem80/blob/master/XR.Z80
;
; md.asm - ROMWBW memory disk driver
; https://github.com/wwarthen/RomWBW/blob/master/Source/HBIOS/md.asm
;
;*****************************************************************************
;
#INCLUDE	"std.asm"
;
HBX_BNKSEL	.EQU	$FE2B
HBX_START	.EQU	$FE00
;
#DEFINE	HB_DI	DI
#DEFINE	HB_EI	EI
;
XFUDBG		.EQU	0
;
		.ORG    USR_LOC
;
; ASCII codes
;
LF:		.EQU	'J'-40h		; ^J LF
CR: 		.EQU 	'M'-40h		; ^M CR/ENTER
SOH:		.EQU	'A'-40h		; ^A CTRL-A
EOT:		.EQU	'D'-40h		; ^D = End of Transmission
ACK:		.EQU	'F'-40h		; ^F = Positive Acknowledgement
NAK:		.EQU	'U'-40h		; ^U = Negative Acknowledgement
CAN:		.EQU	'X'-40h		; ^X = Cancel
BSPC:		.EQU	'H'-40h		; ^H = Backspace
;
; Start of code
;
	LD	(oldSP),SP		; SETUP STACK BELOW HBIOS
	LD	SP,HBX_START-MD_CSIZ	; ALLOW FOR RELOCATABLE CODE AREA

	LD	HL,msgHeader		; PRINT
	CALL	PRTSTR0			; GREETING

	LD	HL,MD_FSTART		; COPY FLASH
	LD	DE,HBX_START-MD_CSIZ	; ROUTINES TO
	LD	BC,MD_CSIZ		; HIGH MEMORY
	LDIR
;
	LD	BC,$F8F2		; LOOKUP
	RST	08			; CURRENT	
	LD	B,$FA			; CONSOLE
	LD	HL,$112			; DEVICE
	RST	08			; TO USE AS
	LD	A,E			; DEFAULT
	LD	(CONDEV),A
;
	LD	BC,$F8F2		; LOOKUP
	RST	08			; CURRENT	
	LD	B,$FA			; SERIAL
	LD	HL,$110			; DEVICE
	RST	08			; TO USE AS
	LD	A,E			; DEFAULT
	LD	(SERDEV),A
;
RESTART:
;	LD	DE,$0000		; SET UP
;	LD	HL,$0000		; START
;	CALL	MD_CALBAS		; BANK AND SECTOR
	LD	DE,$0000
	LD	(MD_FBAS),DE

	LD	HL,MD_FIDEN		; IDENTIFY CHIP
	CALL	MD_FNCALL		; AT THIS BANK/SECTOR
	LD	HL,$B7BF		; FAIL
	XOR	A			; IF FLASH
	SBC	HL,BC			; CHIP IS
	JP	NZ,FAILBC		; NOT SUPPORTED

	LD	BC,$F8F0		; GET CPU SPEED
	RST	08			; AND MULTIPLY
	LD	A,L			; BY 4
	ADD	A,A			; TO CREATE
	ADD	A,A			; TIMOUT DELAY
	LD	(TmoFct),A		; FACTOR 
;
MENULP:	CALL	MENU			; DISPLAY MENU
	CALL	GETINP			; GET SELECTION
;
	CP	'U'			; BEGIN
	JR	Z,BEGUPD		; TRANSFER
;
	CP	'V'			; CHECK FOR
	JP	Z,OPTIONV		; VERIFY TOGGLE
;
	CP	'X'			; CHECK FOR
	JP	Z,FAILUX		; USER EXIT
;
	CP	'R'			; CHECK FOR
	JP	Z,REBOOT		; COLD REBOOT REQUEST
;
	CP	'C'			; CHECK FOR
	JP	Z,OPTIONC		; CONSOLE CHANGE
;
	CP	'S'			; CHECK FOR
	JP	Z,OPTIONS		; SERIAL CHANGE
;
	CP	'D'			; DUPLICATE
	JP	Z,OPTIOND		; FLASH
;
#IF	(XFUDBG)
	CP	'T'			; TEST TIMEOUT
	JP	Z,OPTIONT		; LOOP
;
	CP	'H'			; HALF
	JP	Z,OPTIONH		; SPEED SWITCH
#ENDIF
;
	JR	MENULP
;
BEGUPD:	CALL	SERST			; EMPTY SERIAL BUFFER
	OR	A			; SO WE HAVE A CLEAN
	JR	Z,SERCLR		; START ON TRANSFER
	CALL	SERIN
	JR	BEGUPD
;
SERCLR:	LD	HL,msgInstr		; PROVIDE
	CALL	PRTSTR0			; INSTRUCTION
;
	LD	A,(SERDEV)		; IF CONSOLE AND SERIAL
	LD	HL,CONDEV		; DEVICE ARE THE SAME,
	SUB	(HL)			; BLOCK ALL TEXT
	LD	(BLKCOUT),A		; OUTPUT DURING TRANSFER
;
	LD 	A,1			; THE FIRST PACKET IS NUMBER 1
	LD 	(pktNo),A
	LD 	A,255-1			; ALSO STORE THE 1-COMPLEMENT OF IT
	LD 	(pktNo1c),A
;
	LD	DE,sector4k		; POINT TO START OF SECTOR TO WRITE
;
GetNewPacket:
	LD	A,20			; WE RETRY 20 TIMES BEFORE GIVING UP
	LD 	(retrycnt),A
;
NPloop:	LD 	B,5 			; 5 SECONDS OF TIMEOUT BEFORE EACH NEW BLOCK
	CALL	GetCharTmo
	jp 	NC,NotPacketTimeout
;
	LD	HL,retrycnt		; REACHED MAX NUMBER OF RETRIES?
	dec 	(HL)
	jp 	Z,FAILRT		; YES, PRINT MESSAGE AND EXIT
;
	LD 	C,NAK			; SEND A NAK TO THE UPLOADER
	CALL	SEROUT
	JR 	NPloop
;
NotPacketTimeout:
	cp	EOT			; DID UPLOADER SAY WE'RE FINISHED?
	JP	Z,Done			; YES, THEN WE'RE DONE
	cp 	CAN			; UPLOADER WANTS TO FAIL TRANSFER?
	jp 	Z,FAILCN		; YES, THEN WE'RE ALSO DONE
	cp	SOH			; DID WE GET A START-OF-NEW-PACKET?
	JR	NZ,NPloop		; NO, GO BACK AND TRY AGAIN
;
	LD	HL,packet		; SAVE THE RECEIVED CHAR INTO THE...
	LD	(HL),A			; ...PACKET BUFFER AND...
	INC 	HL			; ...POINT TO THE NEXT LOCATION
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A                  ; SHOULD BE PACKET NUMBER
	INC 	HL
	JP	C,FAILTO
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A			; SHOULD BE PACKET NUMBER
	INC 	HL                      ; COMPLEMENT
	JP	C,FAILTO
;
	LD 	C,128			; GET 128 MORE CHARACTERS FOR A FULL PACKET
GetRestOfPacket:
	CALL	GetCharTmo1		; GET CHARACTER
	JP	C,FAILTO
;
	LD	(HL),A
	INC 	HL			; SAVE THE RECEIVED CHAR INTO THE...
	LD	(DE),A                  ; ...PACKET BUFFER AND...
	INC	DE                      ; ...POINT TO THE NEXT LOCATION
;
	DEC	C
	JR	NZ,GetRestOfPacket
;
	CALL	GetCharTmo1		; GET CHARACTER
	LD	(HL),A                  ; SHOULD BE CHECKSUM
	JP	C,FAILTO
;
	LD	HL,packet+3		; CALCULATE CHECKSUM FROM 128 BYTES OF DATA
	LD	B,128
	XOR	A
csloop:	add	A,(HL)			; JUST ADD UP THE BYTES
	INC	HL
	DJNZ	csloop
;
	XOR	(HL)			; HL POINTS TO THE RECEIVED CHECKSUM SO
	JP	NZ,FAILCS		; BY XORING IT TO OUR SUM WE CHECK FOR EQUALITY
;
	LD	HL,(pktNo)		; CHECK
	LD	BC,(packet+1)		; AGREEMENT
;	XOR	A                       ; PACKET
	SBC	HL,BC                   ; NUMBERS
	JP	NZ,FAILPN
;
	LD	HL,pktNo		; HAVE WE RECEIVED
	LD	A,(HL)			; A BLOCK OF 32
	DEC	A			; XMODEM PACKETS?
	AND	%00011111		; IF YES THEN WERE WE
	CP	%00011111		; HAVE ENOUGH TO
	LD	A,0			; WRITE A FLASH SECTOR
	CALL	Z,WSEC			; ASSUME FLASH SUCCESSFUL
;
	OR	A			; EXIT IF WE GOT A
	JP	NZ,FAILWF		; WRITE VERIFICATION ERROR

	LD	HL,pktNo		; UPDATE THE PACKET COUNTERS
	INC 	(HL)
	INC	HL
	DEC	(HL)
;
	LD 	C,ACK			; TELL UPLOADER THAT WE'RE HAPPY WITH WITH
	CALL	SEROUT			; PACKET AND GO BACK AND FETCH SOME MORE
;
	JP	GetNewPacket
;
COUTON:	LD	A,$FF			; TURN ON 
	LD	(BLKCOUT),A		; OUTPUT
	RET
;
Done:	LD	C,ACK			; TELL UPLOADER 
	CALL	SEROUT			; WE'RE DONE
Done1:	LD 	HL,msgSuccess		; BACK TO
	JR	MSGRS			; MENU
;
FAILTO:	LD	HL,msgTimout		; TIMOUT WAITING 
	JR	ERRRX			; FOR CHARACTER
;
FAILWF:	LD	HL,msgFailWrt		; FLASH
	JR	MSGRS			; VERIFY FAIL
;
FAILRT:	LD	HL,msgRetry		; RETRY
	JR	ERRRX			; TIMEOUT FAIL
;
FAILCS:	LD	HL,msgChkSum		; CHECKSUM
	JR	ERRRX			; ERROR
;
FAILPN:	LD	HL,msgPacErr		; PACKET
	JR	ERRRX			; NUMBER ERROR
;
FAILCN:	LD 	HL,msgCancel		; TRANSMISSION
	JR	ERRRX			; FAILURE
;
FAILUX:	LD	HL,msgUserEx		; USER
	JR	Die			; EXIT
;
FAILBC:	LD	HL,msgUnsupC		; UNSUPPORTED
	JR	Die			; FLASH CHIP
;
ERRRX:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; DISPLAY TRANSMISSION
	LD	HL,msgFailure		; RECEIPT ERROR
	CALL 	PRTSTR0
	JP	RESTART
;
MSGRS:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; DISPLAY
	JP	RESTART			; MESSAGE
;
REBOOT:	LD	HL,msgReboot		; REBOOT MESSAGE
	CALL 	PRTSTR0
	LD	C,BF_SYSRES_COLD	; COLD RESTART
	JR	Die1
;
Die:	CALL	COUTON			; TURN ON OUTPUT
	CALL 	PRTSTR0			; Prints message and exits from program
	LD	C,BF_SYSRES_WARM	; WARM START
Die1:	LD	B,BF_SYSRESET		; SYSTEM RESTART
	LD	SP,(oldSP)
	CALL	$FFF0			; CALL HBIOS
	RET

WSEC:	PUSH	HL			; WRITE A
	PUSH	BC			; FLASH
	PUSH	DE			; SECTOR
;
	CALL	DISPROG			; DISPLAY PROGRESS
;
WSEC1:	LD	HL,MD_FERAS		; ERASE
	CALL	MD_FNCALL		; AND WRITE
	LD	IX,sector4k		; THIS
	LD	HL,MD_FWRIT		; BANK / SECTOR
	CALL	MD_FNCALL
;
	LD	A,(WRTVER)		; VERIFY
	OR	A			; WRITE IF
	JR	Z,NOVER			; OPTION SET
;
	LD	IX,sector4k		; VERIFY
	LD	HL,MD_FVERI		; WRITE
	CALL	MD_FNCALL
	LD	(VERRES),A		; SAVE STATUS
;
NOVER:	POP	DE			; POINT BACK TO
	LD	DE,sector4k		; START OF 4K BUFFER
	PUSH	DE
;
	LD	HL,MD_FBAS
	LD	A,(HL)			; DID WE JUST
	SUB	$70			; DO LAST
	JR	NZ,NXTS2		; SECTOR
;
	LD	(HL),A			; RESET SECTOR TO 0
	INC	HL
	INC	(HL)			; NEXT BANK
	JR	NXTS3
;
NXTS2:	LD	A,$10			; NEXT SECTOR
	ADD	A,(HL)			; EACH SECTOR IS $1000
	LD	(HL),A			; BUT WE JUST INCREASE HIGH BYTE
;
NXTS3:	LD	A,(VERRES)		; EXIT WITH STATUS
	POP	DE
	POP	BC
	POP	HL
	RET
;
DISPROG:LD	A,(BLKCOUT)		; SKIP OUTPUT
	OR	A			; IF OUTPUT
	RET	Z			; BLOCKED
;
	LD	A,(MD_SECT)		; IF SECTOR IS 0
	OR	A			; THEN DISPLAY
	JR	NZ,DISP1		; BANK # PREFIX
	LD	HL,msgBank
	CALL	PRTSTR0
	LD	A,(MD_BANK)
	CALL	PRTHEXB
;
DISP1:	LD	C,' '			; DISPLAY
	CALL	CONOUT			; CURRENT
	LD	C,'S'			; SECTOR
	CALL	CONOUT
	LD	A,(MD_SECT)
	RRCA
	RRCA
	RRCA
	RRCA
	CALL	PRTHEXB
	RET
;
; WAITS FOR UP TO A SECONDS FOR A CHARACTER TO BECOME AVAILABLE AND
; RETURNS IT IN A WITHOUT ECHO AND CARRY CLEAR. IF TIMEOUT THEN CARRY
; IT SET.
;
; 4MHZ  20 SECONDS B=16
; 10MHZ 20 SECONDS B=39
;
GetCharTmo1:
	LD	B,1
GetCharTmo:
	CALL	SERST			; IF THERE IS A 
	OR	A			; CHARACTER AVAILABLE
	JR 	NZ,GotChrX		; EXIT NOW OTHERWISE POLL
	PUSH	BC
	LD	BC,255			; C=CONSTANT (255) FOR INNER TIMING LOOP
TmoFct:	.EQU	$-1			; B=SPEED FACTOR WHICH GETS UPDATED AT START
GCtmob:	PUSH	BC
	LD	B,C
GCtmoc:	PUSH	BC
	CALL	SERST
	OR	A			; A CHAR AVAILABLE?
	JR 	NZ,GotChar		; YES, GET OUT OF LOOP
	POP	BC
	DJNZ	GCtmoc
	POP	BC
	DJNZ	GCtmob
	POP	BC
	DJNZ	GetCharTmo
	SCF 				; SET CARRY SIGNALS TIMEOUT
	RET
;
GotChar:POP	BC
	POP	BC
	POP	BC
GotChrX:CALL	SERIN
	OR	A 			; CLEAR CARRY SIGNALS SUCCESS
	RET
;
GETINP:	CALL	CONIN			; GET A CHARACTER
	LD	C,A			; RETURN SEQUENCE
	CALL	CONOUT			; CONVERT TO UPPERCASE
	LD	C,BSPC			; RETURN CHARACTER IN A
	CALL	CONOUT
	LD	B,A
	CP	BSPC
	JR	Z,GETINP
GETINP2:CALL	CONIN
	CP	BSPC
	JR	Z,GETINP
	CP	CR
	JR	NZ,GETINP2
	LD	A,B
	LD	C,A
	CALL	CONOUT
	CP	'a'			; BELOW 'A'?
	JR	C,GETINP3		; IF SO, NOTHING TO DO
	CP	'z'+1			; ABOVE 'Z'?
	JR	NC,GETINP3		; IF SO, NOTHING TO DO
	AND	~$20			; CONVERT CHARACTER TO LOWER
GETINP3:RET
;
PRTSTR0:LD	A,(HL)			; PRINT MESSAGE POINTED TOP HL UNTIL 0
	or	A			; CHECK IF GOT ZERO?
	RET	Z			; IF ZERO RETURN TO CALLER
	LD 	C,A
	CALL	CONOUT			; ELSE PRINT THE CHARACTER
	INC	HL
	JP	PRTSTR0
;
MENU:	LD	HL,msgConsole		; DISPLAY
	CALL	PRTSTR0			; CONSOLE
	LD	A,(CONDEV)		; DEVICE
	ADD	A,'0'
	LD	C,A
	CALL	CONOUT
;
	LD	HL,msgIODevice		; DISPLAY
	CALL	PRTSTR0			; SERIAL
	LD	A,(SERDEV)		; DEVICE
	ADD	A,'0'
	LD	C,A
	CALL	CONOUT
;
	LD	HL,msgWriteV		; DISPLAY
	CALL	PRTSTR0			; VERIFY
	LD	A,(WRTVER)		; OPTION
	OR	A
	LD	HL,msgYES
	JR	NZ,MENU1
	LD	HL,msgNO
MENU1:	CALL	PRTSTR0
;
	LD	HL,msgBegin		; DISPLAY OTHER
	CALL	PRTSTR0			; MENU OPTIONS
	RET
;
OPTIOND:CALL	COUTON			; TURN ON OUTPUT
;
	LD	HL,msgConfirm		; CONFIRM
	CALL	PRTSTR0			; OK
	CALL	GETINP			; TO
	CP	'Y'			; PROCEED
	JP	NZ,MENULP
DUPL:	LD	HL,msgCopying	
	CALL	PRTSTR0		
;
	LD	B,16			; LOOP THROUGH 16 BANKS
;
	XOR	A			; START AT
	LD	(MD_BANK),A		; BANK 0
;
NXTB:	PUSH	BC
;
	XOR	A			; START AT
	LD	(MD_SECT),A		; SECTOR 0
;
	LD	B,8			; LOOP THROUGH 8 SECTORS
NXTS:	PUSH	BC
;	
	CALL	DISPROG			; DISPLAY PROGRESS
;
	LD	IX,sector4k		; READ SECTOR 
	LD	HL,MD_FREAD		; FROM ROM #1
	CALL	MD_FNCALL
;
	LD	HL,MD_BANK		; SET CHIP #2
	SET	4,(HL)
;
	LD	HL,MD_FERAS		; ERASE SECTOR
	CALL	MD_FNCALL		; ON ROM #2
	OR	A
	JR	NZ,VERF
;
	LD	IX,sector4k		; WRITE SECTOR
	LD	HL,MD_FWRIT		; ON ROM #2
	CALL	MD_FNCALL
;
	LD	A,(WRTVER)		; VERIFY
	OR	A			; WRITE IF
	JR	Z,NOVER1		; OPTION
;
	LD	IX,sector4k		; VERIFY
	LD	HL,MD_FVERI		; WRITE
	CALL	MD_FNCALL
	OR	A			; EXIT IF
	JR	NZ,VERF			; VERIFY FAILED
;
NOVER1:	LD	HL,MD_BANK		; RESET TO CHIP #1
	RES	4,(HL)
;
	LD	A,(MD_SECT)		; POINT TO	
	ADD	A,$10			; NEXT
	LD	(MD_SECT),A		; SECTOR
;
	POP	BC			; LOOP
	DJNZ	NXTS			; NEXT SECTOR
;
	LD	HL,MD_BANK		; POINT TO	; 00-15 = CHIP 1
	INC	(HL)			; NEXT BANK	; 16-21 = CHIP 2
;
	POP	BC			; LOOP
	DJNZ	NXTB			; NEXT BANK
;
	JP	Done1			; SUCCESS. RETURN TO MENU
;
VERF:	POP	BC			; EXIT WITH FAIL
	POP	BC			; FAIL MESSAGE AND 
	JP	FAILWF			; RETURN TO MENU
;
OPTIONV:LD	A,(WRTVER)		; TOGGLE
	CPL				; VERIFY
	LD	(WRTVER),A		; FLAG
	JP	MENULP			; BACK TO MENU
;
OPTIONC:LD	HL,msgEnterUnit		; GET
	CALL	PRTSTR0			; CONSOLE
	CALL	GETINP			; UNIT NUMBER
	CP	'0'
	JR	C,CONCLR
	CP	'9' + 1
	JR	NC,CONCLR
	SUB	'0'
	LD	(CONDEV),A
CLRCON:	CALL	CONST			; EMPTY CONSOLE BUFFER
	OR	A			; SO WE DON'T HAVE ANY
	JR	Z,CONCLR		; FALSE ENTRIES
	CALL	CONIN
	JR	CLRCON

CONCLR:	JP	MENULP			; BACK TO MENU
;
OPTIONS:LD	HL,msgEnterUnit		; GET
	CALL	PRTSTR0        		; CONSOLE
	CALL	GETINP         		; UNIT
	CP	'0'
	JR	C,CONCLR
	CP	'9' + 1
	JR	NC,CONCLR
	SUB	'0'            		; NUMBER
	LD	(SERDEV),A
;
	JP	MENULP			; BACK TO MENU
;
#IF	(XFUDBG)
OPTIONT:LD	HL,msgCRLF
	CALL	PRTSTR0
	LD	C,'*'			; DISPLAY START
	CALL	CONOUT			; INDICATOR
	LD	B,20			; DELAY 20
	CALL	GetCharTmo		; SECONDS
	LD	C,'*'			; DISPLAY FINISH
	CALL	CONOUT			; INDICATOR
	JP	MENULP			; BACK TO MENU
;
OPTIONH:LD	A,8			; TURN ON THE SBC-V2-004+
	OUT	(RTCIO),A		; CLOCK DIVIDER
	LD	HL,TmoFct		; AND ADJUST
	SRL	(HL)			; DELAY FACTOR (/2)
	JP	MENULP			; BACK TO MENU
#ENDIF
;
SEROUT:	PUSH	HL			; SERIAL OUTPUT CHARACTER IN C
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$01
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
SERST:	PUSH	HL			; SERIAL STATUS. RETURN CHARACTERS AVAILABLE IN A
	PUSH	DE
	PUSH	BC
	LD	B,$02
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
SERIN:	PUSH	HL			; SERIAL INPUT. WAIT FOR A CHARACTER ADD RETURN IT IN A
	PUSH	DE
	PUSH	BC
	LD	B,$00
	LD	HL,SERDEV
	LD	C,(HL)
	RST	08
	LD	A,E
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONOUT:	PUSH	HL			; CONSOLE OUTPUT CHARACTER IN C
	PUSH	DE			; OUTPUT IS BLOCKED DURING THE
	PUSH	BC			; FILE TRANSFER WHEN THE
	PUSH	AF
	LD	A,(BLKCOUT)		; CONSOLE AND SERIAL LINE
	OR	A			; ARE THE SAME
	JR	Z,CONOUT1
	LD	E,C
	LD	B,$01
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
CONOUT1:POP	AF
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONST:	PUSH	HL			; CONSOLE STATUS. RETURN CHARACTERS AVAILABLE IN A
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$02
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
	POP	BC
	POP	DE
	POP	HL
	RET
;
CONIN:	PUSH	HL			; CONSOLE INPUT. WAIT FOR A CHARACTER ADD RETURN IT IN A
	PUSH	DE
	PUSH	BC
	LD	E,C
	LD	B,$00
	LD	HL,CONDEV
	LD	C,(HL)
	RST	08
	LD	A,E
	POP	BC
	POP	DE
	POP	HL
	RET
;
PRTHEXB:PUSH	AF				; PRINT HEX BYTE IN A TO CONSOLE
	PUSH	DE
	CALL	HEXASC
	LD	C,D
	CALL	CONOUT
	LD	C,E
	CALL	CONOUT
	POP	DE
	POP	AF
	RET

HEXASC:	LD	D,A
	CALL	HEXCONV
	LD	E,A
	LD	A,D
	RLCA
	RLCA
	RLCA
	RLCA
	CALL	HEXCONV
	LD	D,A
	RET
;
HEXCONV:AND	0FH				; CONVERT LOW NIBBLE OF A TO ASCII HEX
	ADD	A,90H
	DAA
	ADC	A,40H
	DAA
	RET
;
;======================================================================
; CALCULATE BANK AND ADDRESS DATA FROM MEMORY ADDRESS
;
; ON ENTRY DE:HL CONTAINS 32 BIT MEMORY ADDRESS.
; ON EXIT  B     CONTAINS BANK SELECT BYTE
;          C     CONTAINS HIGH BYTE OF SECTOR ADDRESS
;======================================================================
;
;MD_CALBAS:
;
;	PUSH	HL
;	LD	A,E			; BOTTOM PORTION OF SECTOR
;	AND	$0F			; ADDRESS THAT GETS WRITTEN
;	RLC	H			; WITH ERASE COMMAND BYTE
;	RLA				; A15 GETS DROPPED OFF AND
;	LD	B,A			; ADDED TO BANK SELECT
;
;	LD	A,H			; TOP SECTION OF SECTOR
;	RRA				; ADDRESS THAT GETS WRITTEN
;	AND	$70			; TO BANK SELECT PORT
;	LD	C,A
;	POP	HL
;
;	LD	(MD_FBAS),BC		; SAVE BANK AND SECTOR FOR USE IN FLASH ROUTINES
;	RET
;
MD_FSTART:	.EQU	$		; FLASH ROUTINES WHICH GET RELOCATED TO HIGH MEMORY
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
;  MD_VERI_R - VERIFY FLASH SECTOR
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
;  COPY FLASH CODE TO UPPER MEMORY
;  CALL RELOCATED FLASH CODE
;  RETURN WITH ID CODE.
;======================================================================
;
MD_FNCALL:
	LD	DE,$0000
	LD	BC,(MD_FBAS)		; PUT BANK AND SECTOR DATA IN BC
;
	EX	AF,AF'
	PUSH	AF
	LD	A,(HB_CURBNK)		; WE ARE STARTING IN HB_CURBNK
;
	HB_DI
	CALL	MD_FJPHL
	HB_EI
;
	POP	AF
	EX	AF,AF'
;
	LD	A,C			; RETURN WITH STATUS IN A
	RET
;
MD_FJPHL:
	JP	(HL)
;
;======================================================================
; FLASH IDENTIFY
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  ISSUE ID COMMAND
;  READ IN ID WORD
;  ISSUE ID EXIT COMMAND
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          A  CONTAINS CURRENT BANK
; ON EXIT  BC CONTAINS ID WORD
;          NO STATUS IS RETURNED
;======================================================================
;
MD_FIDEN_R:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	LD	D,A			; SAVE CURRENT BANK
;
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
;
	LD	HL,$5555		; LD	A,$AA			; COMMAND
	LD	(HL),$AA		; LD	($5555),A		; SETUP
	LD	A,H			; LD	A,$55
	LD	($2AAA),A		; LD	($2AAA),A
	LD	(HL),$90		; LD	A,$90
;					; LD	($5555),A
	LD	BC,($0000)						; READ ID
;
	LD	A,$F0			; LD	A,$F0			; EXIT
	LD	(HL),A			; LD	($5555),A		; COMMAND
;
	LD	A,D			; RETURN TO ORIGINAL BANK
	JP	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;
;======================================================================
; ERASE FLASH SECTOR.
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  ISSUE ERASE SECTOR COMMAND
;  POLL TOGGLE BIT FOR COMPLETION STATUS.
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          A  CONTAINS CURRENT BANK
; ON EXIT  C  RETURNS STATUS 0=SUCCESS NZ=FAIL
;======================================================================
;
MD_FERAS_R:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	EX	AF,AF'			; SAVE CURRENT BANK
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
;
	LD	HL,$5555		; LD	($5555),A
	LD	DE,$2AAA		; LD	A,$55
	LD	A,L			; LD	($2AAA),A
	LD	(HL),E			; LD	A,$80
	LD	(DE),A			; LD	($5555),A
	LD	(HL),$80		; LD	A,$AA
	LD	(HL),E			; LD	($5555),A
	LD	(DE),A			; LD	A,$55
;					; LD	($2AAA),A
	LD	H,C			; SECTOR
	LD	L,$00			; ADDRESS
;
	LD	A,$30			; SECTOR ERASE
	LD	(HL),A			; COMMAND
;
MD_WT4:	LD	A,(HL)			; DO TWO SUCCESSIVE READS
	LD	C,(HL)			; FROM THE SAME FLASH ADDRESS.
	XOR	C			; IF THE SAME ON BOTH READS
	BIT	6,A			; THEN ERASE IS COMPLETE SO EXIT.
;
	JR	Z,MD_WT5		; BIT 6 = 0 IF SAME ON SUCCESSIVE READS = COMPLETE
					; BIT 6 = 1 IF DIFF ON SUCCESSIVE READS = INCOMPLETE
;
	LD	A,C			; OPERATION IS NOT COMPLETE. CHECK TIMEOUT BIT (BIT 5).
	BIT	5,C			; IF NO TIMEOUT YET THEN LOOP BACK AND KEEP CHECKING TOGGLE STATUS
	JR	Z,MD_WT4		; IF BIT 5=0 THEN RETRY; NZ TRUE IF BIT 5=1
;
	LD	A,(HL)			; WE GOT A TIMOUT. RECHECK TOGGLE BIT IN CASE WE DID COMPLETE
	XOR	(HL)			; THE OPERATION. DO TWO SUCCESSIVE READS. ARE THEY THE SAME?
	BIT	6,A			; IF THEY ARE THEN OPERATION WAS COMPLETED
	JR	Z,MD_WT5		; OTHERWISE ERASE OPERATION FAILED OR TIMED OUT.
;
	LD	C,$F0			; COMMON FAIL STATUS / PREPARE DEVICE RESET CODE
	LD	(HL),C			; WRITE DEVICE RESET
	JR	MD_WT6
MD_WT5:	LD	C,L			; SET SUCCESS STATUS
;
MD_WT6:	EX	AF,AF'			; RETURN TO ORIGINAL BANK
	JP	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;
;======================================================================
; FLASH READ SECTOR.
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  READ SECTOR OF 4096 BYTES, BYTE AT A TIME
;  SELECT SOURCE BANK,  READ DATA,
;	   SELECT DESTINATION BANK, WRITE DATA
;          DESTINATION BANK IS ALWAYS CURRENT BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          DE = 0000 BYTE COUNT
;          IX POINTS TO DATA TO BE WRITTEN
;          A  CONTAINS CURRENT BANK
; ON EXIT  NO STATUS RETURNED
;          AF' TRASHED
;======================================================================
;
MD_FREAD_R:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	LD	H,C			; SECTOR
	LD	L,D			; ADDRESS
;
	EX	AF,AF'			; PUT DESTINATION BANK IN AF'
	LD	A,B			; PUT SOURCE BANK IN AF
;
MD_FRD1:
	CALL	HBX_BNKSEL		; READ			; SWITCH TO SOURCE BANK
	LD	C,(HL)			; BYTE
;
	EX	AF,AF'			; SELECT BANK 		; SWITCH DESTINATION BANK
	CALL	HBX_BNKSEL		; TO WRITE
	LD	(IX+0),C		; WRITE BYTE
	EX	AF,AF'			;			; PUT SOURCE BANK IN AF
;
	INC	HL			; NEXT SOURCE LOCATION
	INC	IX			; NEXT DESTINATION LOCATION
;
	INC	DE			; CONTINUE READING UNTIL
	BIT	4,D			; WE HAVE DONE ONE SECTOR
	JR	Z,MD_FRD1
;
	RET
;
;======================================================================
; FLASH VERIFY SECTOR.
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  VERIFY SECTOR OF 4096 BYTES, BYTE AT A TIME
;  SELECT SOURCE BANK,  READ DATA,
;	   SELECT DESTINATION BANK, COMPARE DATA
;          DESTINATION BANK IS ALWAYS CURRENT BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          DE = 0000 BYTE COUNT
;          IX POINTS TO DATA TO BE VERIFIED
;          A  CONTAINS CURRENT BANK
; ON EXIT  C  RETURNS STATUS 0=SUCCESS NZ=FAIL
;======================================================================
;
MD_FVERI_R:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	LD	H,C			; SECTOR
	LD	L,D			; ADDRESS
;
	EX	AF,AF'			; PUT SOURCE BANK IN AF' (RAM)
;
MD_FVE1:
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO READ 			; SWITCH TO FLASH BANK
	LD	A,(HL)			; READ BYTE
;
	EX	AF,AF'			; SELECT BANK			; SWITCH TO RAM BANK
	CALL	HBX_BNKSEL		; TO VERIFY AGAINST
	EX	AF,AF'
;
	SUB	(IX+0)			; COMPARE BYTE
	JR	NZ,MD_FVE2		; EXIT IF MISMATCH
;
	INC	HL			; NEXT SOURCE LOCATION
	INC	IX			; NEXT DESTINATION LOCATION
;
	INC	DE			; CONTINUE READING UNTIL
	BIT	4,D			; WE HAVE DONE ONE SECTOR
	JR	Z,MD_FVE1
;
MD_FVE2:
	LD	C,A			; SET STATUS
	EX	AF,AF'
;
	RET
;
;======================================================================
; FLASH WRITE SECTOR.
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  WRITE 1 SECTOR OF 4096 BYTES, BYTE AT A TIME
;   ISSUE WRITE BYTE COMMAND AND WRITE THE DATA BYTE
;   POLL TOGGLE BIT FOR COMPLETION STATUS.
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          IX POINTS TO DATA TO BE WRITTEN
;          DE = 0000 BYTE COUNT
;          A  CONTAINS CURRENT BANK
; ON EXIT  NO STATUS IS RETURNED
;======================================================================
;
MD_FWRIT_R:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	LD	H,C			; SECTOR
	LD	L,D			; ADDRESS
;
MD_FWRI1:
	CALL	HBX_BNKSEL		; SELECT BANK TO READ
	EX	AF,AF'			; SAVE CURRENT BANK
;
	LD	C,(IX+0)		; READ IN BYTE
;
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
;
	LD	A,$AA			; COMMAND
	LD	($5555),A		; SETUP
	LD	A,$55
	LD	($2AAA),A
;
	LD	A,$A0			; WRITE
	LD	($5555),A		; COMMAND
;
	LD	(HL),C			; WRITE OUT BYTE
;
;					; DO TWO SUCCESSIVE READS
MD_FW7:	LD	A,(HL)			; FROM THE SAME FLASH ADDRESS.
	LD	C,(HL)			; IF TOGGLE BIT (BIT 6)
	XOR	C			; IS THE SAME ON BOTH READS
	BIT	6,A			; THEN WRITE IS COMPLETE SO EXIT.
	JR	NZ,MD_FW7		; Z TRUE IF BIT 6=0 I.E. "NO TOGGLE" WAS DETECTED.
;
	INC	HL			; NEXT DESTINATION LOCATION
	INC	IX			; NEXT SOURCE LOCATION
;
	EX	AF,AF'			; RESTORE CURRENT BANK
;
	INC	DE			; CONTINUE WRITING UNTIL
	BIT	4,D			; WE HAVE DONE ONE SECTOR
	JR	Z,MD_FWRI1
;
	JP	HBX_BNKSEL		; RETURN TO ORIGINAL BANK WHICH IS OUR RAM BIOS COPY
;
MD_FEND		.EQU	$
MD_CSIZ		.EQU	MD_FEND-MD_FSTART	; HOW MUCH SPACE WE NEED FOR RELOCATABLE CODE
;
MD_FIDEN	.EQU	HBX_START-MD_CSIZ+MD_FIDEN_R-MD_FSTART	; CALL ADDRESS FOR IDENTIFY FLASH CHIP
MD_FERAS	.EQU	HBX_START-MD_CSIZ+MD_FERAS_R-MD_FSTART	; CALL ADDRESS FOR ERASE FLASH SECTOR
MD_FREAD 	.EQU	HBX_START-MD_CSIZ+MD_FREAD_R-MD_FSTART	; CALL ADDRESS FOR READ FLASH SECTOR
MD_FVERI 	.EQU	HBX_START-MD_CSIZ+MD_FVERI_R-MD_FSTART	; CALL ADDRESS FOR VERIFY FLASH SECTOR
MD_FWRIT 	.EQU	HBX_START-MD_CSIZ+MD_FWRIT_R-MD_FSTART	; CALL ADDRESS FOR WRITE FLASH SECTOR
;MD_FERAC	.EQU	HBX_START-MD_CSIZ+MD_FERAC_R-MD_FSTART	; CALL ADDRESS FOR ERASE FLASH CHIP
;
; Message strings
;
msgHeader:	.DB 	CR,LF,CR,LF,"ROMWBW XMODEM FLASH UPDATER",CR,LF,0
msgConfirm:	.DB	CR,LF,CR,LF,"ENTER Y TO CONFIRM OVERWRITE : ",0
msgInstr:	.DB	CR,LF,CR,LF,"START TRANSFER OF YOUR UPDATE IMAGE OR ROM",CR,LF,0
msgUserEx:	.DB	CR,LF,"UPDATER EXITED BY USER",CR,LF,0
msgBank:	.DB	CR,LF,"BANK ",0
msgUnsupC:	.DB	CR,LF,"FLASH CHIP NOT SUPPORTED",CR,LF,0
msgReboot:	.DB	CR,LF,"REBOOTING ...",CR,LF,0
msgCopying:	.DB	CR,LF,"COPYING ...",CR,LF,0
msgFailWrt:	.DB	CR,LF,"FLASH WRITE FAILED",CR,LF,0
msgFailure:	.DB	CR,LF,"TRANSMISSION FAILED",CR,LF,0
msgCancel:	.DB	CR,LF,"TRANSMISSION CANCELLED",CR,LF,0
msgConsole:	.DB	CR,LF,"(C) Set Console Device  : ",0
msgIODevice:	.DB	CR,LF,"(S) Set Serial Device   : ",0
msgWriteV:	.DB	CR,LF,"(V) Toggle Write Verify : ",0
msgBegin:	.DB	CR,LF,"(R) Reboot"
		.DB	CR,LF,"(U) Begin Update"
		.DB	CR,LF,"(X) Exit to Rom Loader"
		.DB	CR,LF,"(D) Duplicate Flash #1 to #2"
#IF	(XFUDBG)
		.DB	CR,LF,"(H) Select half speed"
		.DB	CR,LF,"(T) Test 20s timeout"
#ENDIF
		.DB	CR,LF,CR,LF,"Select : ",0
msgSuccess:	.DB	CR,LF,CR,LF,"COMPLETED WITHOUT ERRORS ",CR,LF,0
msgEnterUnit:	.DB	CR,LF,"ENTER UNIT NUMBER : ",0
msgCRLF:	.DB	CR,LF,0
msgYES:		.DB	"YES",0
msgNO:		.DB	"NO",0
msgPacErr:	.DB	CR,LF,"PACKET COUNT MISMATCH ERROR",CR,LF,0
msgChkSum	.DB	CR,LF,"CHECKSUM ERROR",CR,LF,0
msgRetry	.DB	CR,LF,"ERROR, RETRY COUNT EXCEED",CR,LF,0
msgTimout	.DB	CR,LF,"ERROR, RECEIVE TIMEOUT",CR,LF,0
;
; Variables
;
CONDEV:		.DB	$00		; HBIOS CONSOLE DEVICE NUMBER
SERDEV:		.DB	$00		; HBIOS SERIAL DEVICE NUMBER USED FOR XMODEM TRANSFER
WRTVER:		.DB	$FF		; WRITE VERIFY OPTION FLAG
VERRES:		.DB	$00		; WRITE VERIFY RESULT
BLKCOUT:	.DB	$FF		; BLOCK TEXT OUTPUT DURING TRANSFER IF ZERO
oldSP:		.DW	0		; The orginal SP to be restored before exiting
retrycnt:	.DB 	0		; Counter for retries before giving up
chksum:		.DB	0		; For calculating the checksum of the packet
pktNo:		.DB 	0 		; Current packet Number
pktNo1c:	.DB 	0 		; Current packet Number 1-complemented
MD_FBAS		.DW	$FFFF		; CURRENT BANK AND SECTOR
MD_SECT		.EQU	MD_FBAS		;  BANK BYTE
MD_BANK		.EQU	MD_FBAS+1	;  SECTOR BYTE
;
packet:		.DB 	0		; SOH
		.DB	0		; PacketN
		.DB	0		; -PacketNo,
		.FILL	128,0		; data*128,
		.DB	0 		; chksum
;
sector4k:	.EQU	$		; 32 PACKETS GET ACCUMULATED HERE BEFORE FLASHING
;
SLACK		.EQU	(USR_END - $)
		.FILL	SLACK,$FF
		.ECHO	"User ROM space remaining: "
		.ECHO	SLACK
		.ECHO	" bytes.\n"
		.END