;
;==================================================================================================
;   ROMWBW 2.X CONFIGURATION DEFAULTS FOR ZETA V1
;==================================================================================================
;
; THIS FILE CONTAINS THE FULL SET OF DEFAULT CONFIGURATION SETTINGS FOR THE PLATFORM
; INDICATED ABOVE. THIS FILE SHOULD *NOT* NORMALLY BE CHANGED.	INSTEAD, YOU SHOULD
; OVERRIDE ANY SETTINGS YOU WANT USING A CONFIGURATION FILE IN THE CONFIG DIRECTORY
; UNDER THIS DIRECTORY.
;
; THIS FILE CAN BE CONSIDERED A REFERENCE THAT LISTS ALL POSSIBLE CONFIGURATION SETTINGS
; FOR THE PLATFORM.
;
#DEFINE PLATFORM_NAME "ZETA"
;
PLATFORM	.EQU	PLT_ZETA	; PLT_[SBC|ZETA|ZETA2|N8|MK4|UNA|RCZ80|RCZ180|EZZ80|SCZ180|DYNO|RCZ280|MBC]
CPUFAM		.EQU	CPU_Z80		; CPU FAMILY: CPU_[Z80|Z180|Z280]
BIOS		.EQU	BIOS_WBW	; BIOS_[WBW|UNA]: HARDWARE BIOS
BATCOND		.EQU	FALSE		; ENABLE LOW BATTERY WARNING MESSAGE
HBIOS_MUTEX	.EQU	FALSE		; ENABLE REENTRANT CALLS TO HBIOS (ADDS OVERHEAD)
USELZSA2	.EQU	TRUE		; ENABLE FONT COMPRESSION
TICKFREQ	.EQU	50		; DESIRED PERIODIC TIMER INTERRUPT FREQUENCY (HZ)
;
BOOT_TIMEOUT	.EQU	-1		; AUTO BOOT TIMEOUT IN SECONDS, -1 TO DISABLE, 0 FOR IMMEDIATE
;
CPUSPDCAP	.EQU	SPD_FIXED	; CPU SPEED CHANGE CAPABILITY SPD_FIXED|SPD_HILO
CPUSPDDEF	.EQU	SPD_HIGH	; CPU SPEED DEFAULT SPD_UNSUP|SPD_HIGH|SPD_LOW
CPUOSC		.EQU	20000000	; CPU OSC FREQ IN MHZ
INTMODE		.EQU	0		; INTERRUPTS: 0=NONE, 1=MODE 1, 2=MODE 2, 3=MODE 3 (Z280)
DEFSERCFG	.EQU	SER_38400_8N1	; DEFAULT SERIAL LINE CONFIG (SEE STD.ASM)
;
RAMSIZE		.EQU	512		; SIZE OF RAM IN KB (MUST MATCH YOUR HARDWARE!!!)
PLT_RAM_R	.EQU	0		; RESERVE FIRST N KB OF RAM (USUALLY 0)
PLT_ROM_R	.EQU	0		; RESERVE FIRST N KB OR ROM (USUALLY 0)
MEMMGR		.EQU	MM_SBC		; MEMORY MANAGER: MM_[SBC|Z2|N8|Z180|Z280|MBC]
MPCL_RAM	.EQU	$78		; SBC MEM MGR RAM PAGE SELECT REG (WRITE ONLY)
MPCL_ROM	.EQU	$7C		; SBC MEM MGR ROM PAGE SELECT REG (WRITE ONLY)
;
RTCIO		.EQU	$70		; RTC LATCH REGISTER ADR
;
KIOENABLE	.EQU	FALSE		; ENABLE ZILOG KIO SUPPORT
KIOBASE		.EQU	$80		; KIO BASE I/O ADDRESS
;
CTCENABLE	.EQU	FALSE		; ENABLE ZILOG CTC SUPPORT
;
EIPCENABLE	.EQU	FALSE		; EIPC: ENABLE Z80 EIPC (Z84C15) INITIALIZATION
;
SKZENABLE	.EQU	FALSE		; ENABLE SERGEY'S Z80-512K FEATURES
;
WDOGMODE	.EQU	WDOG_NONE	; WATCHDOG MODE: WDOG_[NONE|EZZ80|SKZ]
;
DIAGENABLE	.EQU	FALSE		; ENABLES OUTPUT TO 8 BIT LED DIAGNOSTIC PORT
DIAGPORT	.EQU	$00		; DIAGNOSTIC PORT ADDRESS
DIAGDISKIO	.EQU	TRUE		; ENABLES DISK I/O ACTIVITY ON DIAGNOSTIC LEDS
;
LEDENABLE	.EQU	FALSE		; ENABLES STATUS LED
LEDMODE		.EQU	LEDMODE_RTC	; LEDMODE_[STD|RTC]
LEDPORT		.EQU	RTCIO		; STATUS LED PORT ADDRESS
LEDDISKIO	.EQU	TRUE		; ENABLES DISK I/O ACTIVITY ON STATUS LED
;
DSKYENABLE	.EQU	FALSE		; ENABLES DSKY
DSKYMODE	.EQU	DSKYMODE_V1	; DSKY VERSION: DSKYMODE_[V1|NG]
DSKYPPIBASE	.EQU	$60		; BASE I/O ADDRESS OF DSKY PPI
DSKYOSC		.EQU	3000000		; OSCILLATOR FREQ FOR DSKYNG (IN HZ)
;
BOOTCON		.EQU	0		; BOOT CONSOLE DEVICE
CRTACT		.EQU	FALSE		; ACTIVATE CRT (VDU,CVDU,PROPIO,ETC) AT STARTUP
VDAEMU		.EQU	EMUTYP_ANSI	; VDA EMULATION: EMUTYP_[TTY|ANSI]
ANSITRACE	.EQU	1		; ANSI DRIVER TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
MKYENABLE	.EQU	FALSE		; MSX 5255 PPI KEYBOARD COMPATIBLE DRIVER (REQUIRES TMS VDA DRIVER)
;
DSRTCENABLE	.EQU	TRUE		; DSRTC: ENABLE DS-1302 CLOCK DRIVER (DSRTC.ASM)
DSRTCMODE	.EQU	DSRTCMODE_STD	; DSRTC: OPERATING MODE: DSRTC_[STD|MFPIC]
DSRTCCHG	.EQU	FALSE		; DSRTC: FORCE BATTERY CHARGE ON (USE WITH CAUTION!!!)
;
BQRTCENABLE	.EQU	FALSE		; BQRTC: ENABLE BQ4845 CLOCK DRIVER (BQRTC.ASM)
BQRTC_BASE	.EQU	$50		; BQRTC: I/O BASE ADDRESS
;
INTRTCENABLE	.EQU	FALSE		; ENABLE PERIODIC INTERRUPT CLOCK DRIVER (INTRTC.ASM)
;
RP5RTCENABLE	.EQU	FALSE		; RP5C01 RTC BASED CLOCK (RP5RTC.ASM)
;
HTIMENABLE	.EQU	FALSE		; ENABLE SIMH TIMER SUPPORT
SIMRTCENABLE	.EQU	FALSE		; ENABLE SIMH CLOCK DRIVER (SIMRTC.ASM)
;
DS7RTCENABLE	.EQU	FALSE		; DS7RTC: ENABLE DS-1307 I2C CLOCK DRIVER (DS7RTC.ASM)
DS7RTCMODE	.EQU	DS7RTCMODE_PCF	; DS7RTC: OPERATING MODE: DS7RTC_[PCF]
;
DUARTENABLE	.EQU	FALSE		; DUART: ENABLE 2681/2692 SERIAL DRIVER (DUART.ASM)
;
UARTENABLE	.EQU	TRUE		; UART: ENABLE 8250/16550-LIKE SERIAL DRIVER (UART.ASM)
UARTOSC		.EQU	1843200		; UART: OSC FREQUENCY IN MHZ
UARTINTS	.EQU	FALSE		; UART: INCLUDE INTERRUPT SUPPORT UNDER IM1/2/3
UARTCFG		.EQU	DEFSERCFG	; UART: LINE CONFIG FOR UART PORTS
UARTCASSPD	.EQU	SER_300_8N1	; UART: ECB CASSETTE UART DEFAULT SPEED
UARTSBC		.EQU	TRUE		; UART: AUTO-DETECT SBC/ZETA ONBOARD UART
UARTCAS		.EQU	FALSE		; UART: AUTO-DETECT ECB CASSETTE UART
UARTMFP		.EQU	FALSE		; UART: AUTO-DETECT MF/PIC UART
UART4		.EQU	FALSE		; UART: AUTO-DETECT 4UART UART
UARTRC		.EQU	FALSE		; UART: AUTO-DETECT RC UART
;
ASCIENABLE	.EQU	FALSE		; ASCI: ENABLE Z180 ASCI SERIAL DRIVER (ASCI.ASM)
;
Z2UENABLE	.EQU	FALSE		; Z2U: ENABLE Z280 UART SERIAL DRIVER (Z2U.ASM)
;
ACIAENABLE	.EQU	FALSE		; ACIA: ENABLE MOTOROLA 6850 ACIA DRIVER (ACIA.ASM)
;
SIOENABLE	.EQU	FALSE		; SIO: ENABLE ZILOG SIO SERIAL DRIVER (SIO.ASM)
;
XIOCFG		.EQU	DEFSERCFG	; XIO: SERIAL LINE CONFIG
;
VDUENABLE	.EQU	FALSE		; VDU: ENABLE VDU VIDEO/KBD DRIVER (VDU.ASM)
CVDUENABLE	.EQU	FALSE		; CVDU: ENABLE CVDU VIDEO/KBD DRIVER (CVDU.ASM)
NECENABLE	.EQU	FALSE		; NEC: ENABLE NEC UPD7220 VIDEO/KBD DRIVER (NEC.ASM)
TMSENABLE	.EQU	FALSE		; TMS: ENABLE TMS9918 VIDEO/KBD DRIVER (TMS.ASM)
TMSTIMENABLE	.EQU	FALSE		; TMS: ENABLE TIMER INTERRUPTS (REQUIRES IM1)
VGAENABLE	.EQU	FALSE		; VGA: ENABLE VGA VIDEO/KBD DRIVER (VGA.ASM)
;
MDENABLE	.EQU	TRUE		; MD: ENABLE MEMORY (ROM/RAM) DISK DRIVER (MD.ASM)
MDROM		.EQU	TRUE		; MD: ENABLE ROM DISK
MDRAM		.EQU	TRUE		; MD: ENABLE RAM DISK
MDTRACE		.EQU	1		; MD: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
MDFFENABLE	.EQU	FALSE		; MD: ENABLE FLASH FILE SYSTEM 
;
FDENABLE	.EQU	TRUE		; FD: ENABLE FLOPPY DISK DRIVER (FD.ASM)
FDMODE		.EQU	FDMODE_ZETA	; FD: DRIVER MODE: FDMODE_[DIO|ZETA|ZETA2|DIDE|N8|DIO3|RCSMC|RCWDC|DYNO|EPFDC|MBC]
FDCNT		.EQU	1		; FD: NUMBER OF FLOPPY DRIVES ON THE INTERFACE (1-2)
FDTRACE		.EQU	1		; FD: TRACE LEVEL (0=NO,1=FATAL,2=ERRORS,3=ALL)
FDMEDIA		.EQU	FDM144		; FD: DEFAULT MEDIA FORMAT FDM[720|144|360|120|111]
FDMEDIAALT	.EQU	FDM720		; FD: ALTERNATE MEDIA FORMAT FDM[720|144|360|120|111]
FDMAUTO		.EQU	TRUE		; FD: AUTO SELECT DEFAULT/ALTERNATE MEDIA FORMATS
;
RFENABLE	.EQU	FALSE		; RF: ENABLE RAM FLOPPY DRIVER
;
IDEENABLE	.EQU	FALSE		; IDE: ENABLE IDE DISK DRIVER (IDE.ASM)
;
PPIDEENABLE	.EQU	FALSE		; PPIDE: ENABLE PARALLEL PORT IDE DISK DRIVER (PPIDE.ASM)
PPIDETRACE	.EQU	1		; PPIDE: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
PPIDECNT	.EQU	1		; PPIDE: NUMBER OF PPI CHIPS TO DETECT (1-3), 2 DRIVES PER CHIP
PPIDE0BASE	.EQU	$60		; PPIDE 0: PPI REGISTERS BASE ADR
PPIDE0A8BIT	.EQU	FALSE		; PPIDE 0A (MASTER): 8 BIT XFER
PPIDE0B8BIT	.EQU	FALSE		; PPIDE 0B (SLAVE): 8 BIT XFER
;
SDENABLE	.EQU	FALSE		; SD: ENABLE SD CARD DISK DRIVER (SD.ASM)
SDMODE		.EQU	SDMODE_PPI	; SD: DRIVER MODE: SDMODE_[JUHA|N8|CSIO|PPI|UART|DSD|MK4|SC|MT]
SDPPIBASE	.EQU	$60		; SD: BASE I/O ADDRESS OF PPI FOR PPI MODDE
SDCNT		.EQU	1		; SD: NUMBER OF SD CARD DEVICES (1-2), FOR DSD & SC ONLY
SDTRACE		.EQU	1		; SD: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
SDCSIOFAST	.EQU	FALSE		; SD: ENABLE TABLE-DRIVEN BIT INVERTER IN CSIO MODE
;
PRPENABLE	.EQU	FALSE		; PRP: ENABLE ECB PROPELLER IO BOARD DRIVER (PRP.ASM)
;
PPPENABLE	.EQU	FALSE		; PPP: ENABLE ZETA PARALLEL PORT PROPELLER BOARD DRIVER (PPP.ASM)
PPPBASE		.EQU	$60		; PPP: PPI REGISTERS BASE ADDRESS
PPPSDENABLE	.EQU	TRUE		; PPP: ENABLE PPP DRIVER SD CARD SUPPORT
PPPSDTRACE	.EQU	1		; PPP: SD CARD TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
PPPCONENABLE	.EQU	TRUE		; PPP: ENABLE PPP DRIVER VIDEO/KBD SUPPORT
;
HDSKENABLE	.EQU	FALSE		; HDSK: ENABLE SIMH HDSK DISK DRIVER (HDSK.ASM)
;
PIO_4P		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR ECB 4P BOARD
PIO_ZP		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR ECB ZILOG PERIPHERALS BOARD (PIO.ASM)
PIO_SBC		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR 8255 CHIP
PIOSBASE	.EQU	$60		; PIO: PIO REGISTERS BASE ADR FOR SBC PPI
;
UFENABLE	.EQU	FALSE		; UF: ENABLE ECB USB FIFO DRIVER (UF.ASM)
;
SN76489ENABLE	.EQU	FALSE		; SN76489 SOUND DRIVER
AY38910ENABLE	.EQU	FALSE		; AY: AY-3-8910 / YM2149 SOUND DRIVER
SPKENABLE	.EQU	FALSE		; SPK: ENABLE RTC LATCH IOBIT SOUND DRIVER (SPK.ASM)
;
DMAENABLE	.EQU	FALSE		; DMA: ENABLE DMA DRIVER (DMA.ASM)
DMABASE		.EQU	$E0		; DMA: DMA BASE ADDRESS
DMAMODE		.EQU	DMAMODE_NONE	; DMA: DMA MODE (NONE|ECB|Z180|Z280|RC|MBC)
