;**************************************************************************************
;                             CLOCK TIMER
;Este programa permite el conteo con minutero y segundero de dos relojes con 4 displays 
;de 7 segmentos cada uno, utilizando el PIC16F84A. Un conversor de BCD a siete segmentos 
;(74LS47), es conectado a las salidas RB0, RB1, RB2 y RB3, (A,B,C,D) respectivamente, 
;mientras que la seleccion de display multiplexada se hace mediante las lineas RB4, RB5 RB6 
;conectadas a A,B,C de un decodificador de 3 a 8 respectivamente, (74LS138).
;Los displays son actualizados cada 5ms para una rata de multiplexacion de 20 ms, el TMRO
;es utilizado como generador de las interrupciones cada 5ms.
;
;						Abel Surace y Hugo Hernández 16/01/2000
;                                               MPLAB for Windows 4.12.12
;                                               Refactored Abel Surace 05/13/2021
;                                               MPLAB for Linux 5.35
;						
;
;Esta versión maneja temporales de reloj.  Tiene conteo descendente.
;***************************************************************************************
#include "p16f84.inc"

; CONFIG
; __config 0x3FF9
 __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF
 
;
TempC	equ	0x0c
TempD	equ	0x0d
TecStatus	equ	0x0e
TecTemp	equ	0x0f
Count1	equ	0x10
Count2	equ	0x11
CountP	equ	0x12
HraTime1	equ	0x13
MinTime1	equ	0x14
SegTime1	equ	0x15
HraTime2	equ	0x16
MinTime2	equ	0x17
SegTime2	equ	0x18
HraTemp	equ	0x19
MinTemp	equ	0x1a
SegTemp	equ	0x1b
FPausa	equ	0x1c
FJ1	equ	0x1d
FJ2	equ	0x1e
FMas	equ	0x1f
FMenos	equ	0x20
Puntos1	equ	0x21
Puntos2	equ	0x22
Countagain equ	0x23
Countagain1 equ	0x24	
Pausa	equ	H'0000'
J1	equ	H'0001'
J2	equ	H'0002'
Mas	equ	H'0003'
Menos	equ	H'0004'
HraMin	equ	H'0005'
OptionReg equ	1
PCL	equ	2
BcdMsd	equ	26
Bcd	equ	27
;
	org	0
	goto	start
;
	org	4
	goto	ServiceInterrupts
;
start
	call	InitPorts
	call	InitTimers
loop
	goto	loop
;
InitPorts
	bsf	STATUS,RP0	;Selecciona el banco 1
	movlw	H'1f'		;carga w con 1f
	movwf	TRISA		;pone el puerto A como entrada
	clrf	TRISB		;pone el puerto B como salida
	bcf	STATUS,RP0	;Selecciona el banco 0
	clrf	PORTA		;Borra las entradas en puerto A
	clrf	PORTB		;Borra las salidas en puerto B
	return
;
;La velocidad del reloj es de 4MHZ, dividido por una preescala de 32 determina que TMRO
;se incrementara cada 31.25us. Si tmro es precargado con 96 tomara (256-176)*31.25us para
;entrar en sobreflujo i.e 5ms. Asi que se obtiene una interrupcion cada 5ms.
;
InitTimers
	clrf	HraTime1		;Borra timers
	clrf	MinTime1		;	/
	clrf	SegTime1		;	/
	clrf	HraTime2		;       /
	clrf	MinTime2		;       /
	clrf	SegTime2		;	/
	clrf	HraTemp			;	/
	clrf	MinTemp			;	/
	clrf	SegTemp			;	/
	clrf	Count1		;Pone contador primer clock en 00
	clrf	Count2		;Pone contador segundo clock en 00
	clrf	CountP		;Pone en 0
	movlw	0x02
	movwf	Puntos1
	movwf	Puntos2
	movlw	0x08
	movwf	TecStatus	;Pone a 08 las teclas (Ascendente)
	clrf	FPausa		;Pone a 0 los Bits de FPausa
	clrf	FJ1		;Pone a 0 los Bits de FJ1
	clrf	FJ2		;Pone a 0 los Bits de FJ2
	clrf	FMas		;Pone a 0 los Bits de FMas
	clrf	FMenos		;Pone a 0 los Bits de FMenos
	clrf	TempC		;Borra el contador de digitos
	bsf	STATUS,RP0	;Selecciona banco 1
	movlw	B'10000100'	;asigna ps a TMR0
	movwf	OptionReg       ;ps = 32
	bcf	STATUS,RP0	;Selecciona banco 0
	movlw	B'00100000'	;Activa interrupcion TMR0
	movwf	INTCON		;
	movlw	.176		;Establece TMR0 en 128
	movwf	TMR0		;
	retfie
;
ServiceInterrupts
	btfsc	INTCON,T0IF	;Interrupcion TMR0 ?
	goto	ServiceTMR0	;Si entonces atienda interrupcion
	movlw	B'00100000'	;No entonces activa para siguiente interrupcion
	movwf	INTCON		;
	retfie			;Retorno de falsa Interrupcion
;
ServiceTMR0
	movlw	.176		;inicia TMR0 en 128
	movwf	TMR0		;
	bcf	INTCON,T0IF	;Borra bandera de interrupcion, alista la siguiente
	call	DelayTec	;llama rutina de Retardo de Rebote
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x1f		;Extrae los 5 primeros bits
	xorlw	0x0a		;Le toca a J1?
	btfsc	STATUS,Z	;No entonces salta
	call	IncTimer1	;llama rutina de incremento a timer2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x1f		;Extrae los 5 primeros bits
	xorlw	0x12		;Le toca a J1?
	btfsc	STATUS,Z	;No entonces salta
	call	DecTimer1	;llama rutina de decremento a timer2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x1f		;Extrae los 5 primeos bits
	xorlw	0x0c		;Le toca a J2?
	btfsc	STATUS,Z	;No entonces salta
	call	IncTimer2	;llama rutina de incremento a timer1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x1f		;Extrae los 5 primeos bits
	xorlw	0x14		;Le toca a J2?
	btfsc	STATUS,Z	;No entonces salta
	call	DecTimer2	;llama rutina de decremento a timer1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x0b		;Mas al Reloj 1?
	btfsc	STATUS,Z	;No entonces salta
	call	IncHra2		;llama rutina de incremento a de Horas 1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x13		;Menos al Reloj 1?
	btfsc	STATUS,Z	;No entonces salta
	call	DecHra2		;llama rutina de decremento de Horas 1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x0d		;Mas al Reloj 2?
	btfsc	STATUS,Z	;No entonces salta
	call	IncHra1		;llama rutina de incremento de Horas 2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x15		;Menos al Reloj 2?
	btfsc	STATUS,Z	;No entonces salta
	call	DecHra1		;llama rutina de decremento de Horas 2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x2b		;Mas al Reloj 1?
	btfsc	STATUS,Z	;No entonces salta
	call	IncMin2		;llama rutina de incremento a timer1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x33		;Menos al Reloj 1?
	btfsc	STATUS,Z	;No entonces salta
	call	DecMin2		;llama rutina de decremento a minutos1
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x2d		;Mas al Reloj 2?
	btfsc	STATUS,Z	;No entonces salta
	call	IncMin1		;llama rutina de incremento a timer2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x3f		;Extrae los 6 primeros bits
	xorlw	0x35		;Menos al Reloj 2?
	btfsc	STATUS,Z	;No entonces salta
	call	DecMin1		;llama rutina de decremento a minutos 2
;
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x01		;Extrae el bit de pausa
	xorlw	0x01		;Esta en Pausa?
	btfsc	STATUS,Z	;No entonces salta
	call	NoSignos	;Pone a 0 los bits de signo
;
	call 	UpdateDisplay	;Update Display
	retfie			;Retorno de interrupcion
;
NoSignos
	bcf	TecStatus,Mas	;Pone 0 en Mas
	bcf	TecStatus,Menos	;Pone 0 en Menos
	movlw	0x0f
	movwf	Puntos2
	movwf	Puntos1
	return
;
DelayTec
	incf	CountP,W	;Incrementa el contador y se guarda en W, CountP no cambia
	xorlw	.10		;Verifica si CountP llega a 10
	btfsc	STATUS,Z	;No entonces retorna
	goto	LeeTeclas	;Si es 50 entonces llama a LeeTeclas
	incf	CountP,F	;incrementa el contador y lo guarda en CountP
	return			
;
LeeTeclas
	clrf	CountP		;Borra el contador
	call	FlancoP
	call	FlancoJ1
	call	FlancoJ2
	call	FlancoMas
	call	FlancoMenos
	return
;
FlancoP
	rlf	FPausa,F	;Rota a la izq el FPausa
	btfsc	PORTA,Pausa	;Si Pausa esta en cero salta
	bsf	FPausa,0	;Coloca en 1 el bit 0 de FPausa
	btfss	PORTA,Pausa	;Si Pausa esta en uno salta
	bcf	FPausa,0	;Coloca en 0 el bit 0 de FPausa
	movf	FPausa,W	;Guarda FPausa en W
	andlw	0x03		;Extrae el bit 0 y 1
	xorlw	0x01		;Hay FPausa de subida?
	btfsc	STATUS,Z	;No entonces salta
	call	ToggleP		;Toggle de Pausa
	return
;
ToggleP
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto	CeroP
	movf	TecStatus,W
	movwf	TecTemp
	bsf	TecStatus,Pausa		;Coloca en 1 el bit de Pausa
	bcf	TecStatus,Mas		;Coloca en 0 el bit de Mas
	bcf	TecStatus,Menos		;Coloca en 0 el bit de Menos
	bcf	TecStatus,HraMin	;Coloca en 0 el bit de Hora/Minuto
	return
;
CeroP	movf	TecTemp,W
	movwf	TecStatus
	bcf	TecStatus,J1		;Desactiva J1
	bcf	TecStatus,J2		;Desactiva J2
	bcf	TecStatus,HraMin	;Coloca en 0 el bit de Hora/Minuto
	return
;
FlancoJ1
	rlf	FJ1,F		;Rota a la izq el FJ1
	btfsc	PORTA,J1	;Si J1 esta en cero salta
	bsf	FJ1,0		;Coloca en 1 el bit 0 de FJ1
	btfss	PORTA,J1	;Si J1 esta en uno salta
	bcf	FJ1,0		;Coloca en 0 el bit 0 de FJ1
	movf	FJ1,W		;Guarda FJ1 en W
	andlw	0x03		;Extrae el bit 0 y 1
	xorlw	0x01		;Hay FJ1 de subida?
	btfsc	STATUS,Z	;No entonces salta
	call	PulsaJ1
	return
;
PulsaJ1
	bsf	TecStatus,J1
	bcf	TecStatus,J2
	btfsc	TecStatus,Pausa		;Si Pausa esta en cero salta
	goto	SelHraMin		;Cambia para ajustar Hora o Minuto
	bcf	TecStatus,HraMin	;Pone a Hora
	return
;
FlancoJ2
	rlf	FJ2,F		;Rota a la izq el FJ2
	btfsc	PORTA,J2	;Si J2 esta en cero salta
	bsf	FJ2,0		;Coloca en 1 el bit 0 de FJ2
	btfss	PORTA,J2	;Si J2 esta en uno salta
	bcf	FJ2,0		;Coloca en 0 el bit 0 de FJ2
	movf	FJ2,W		;Guarda FJ2 en W
	andlw	0x03		;Extrae el bit 0 y 1
	xorlw	0x01		;Hay FJ2 de subida?
	btfsc	STATUS,Z	;No entonces salta
	call	PulsaJ2
	return
;
PulsaJ2
	bcf	TecStatus,J1
	bsf	TecStatus,J2
	btfsc	TecStatus,Pausa		;Si Pausa esta en cero salta
	goto	SelHraMin		;Cambia para ajustar Hora o Minuto
	bcf	TecStatus,HraMin	;Pone a Hora
	return
;
SelHraMin
	btfsc	TecStatus,HraMin	;Si esta 0 en Hora salta
	goto	PoneHora
	bsf	TecStatus,HraMin	;Coloca 1 a Minuto
	return
PoneHora
	bcf	TecStatus,HraMin	;Coloca en 0 a Hora
	return
;
FlancoMas
	rlf	FMas,F		;Rota a la izq el FMas
	btfsc	PORTA,Mas	;Si Mas esta en cero salta
	bsf	FMas,0		;Coloca en 1 el bit 0 de FMas
	btfss	PORTA,Mas	;Si Mas esta en uno salta
	bcf	FMas,0		;Coloca en 0 el bit 0 de FMas
	movf	FMas,W		;Guarda FMas en W
	andlw	0x03		;Extrae el bit 0 y 1
	xorlw	0x01		;Hay FMas de subida?
	btfsc	STATUS,Z	;No entonces salta
	call	ActivaMas
	return
;
ActivaMas
	bsf	TecStatus,Mas	;Pone 1 en Mas
	bcf	TecStatus,Menos	;Pone 0 en Menos
	return
;
FlancoMenos
	rlf	FMenos,F	;Rota a la izq el FMenos
	btfsc	PORTA,Menos	;Si Menos esta en cero salta
	bsf	FMenos,0	;Coloca en 1 el bit 0 de FMenos
	btfss	PORTA,Menos	;Si Menos esta en uno salta
	bcf	FMenos,0	;Coloca en 0 el bit 0 de FMenos
	movf	FMenos,W	;Guarda FMenos en W
	andlw	0x03		;Extrae el bit 0 y 1
	xorlw	0x01		;Hay FMenos de subida?
	btfsc	STATUS,Z	;No entonces salta
	call	ActivaMenos
	return
;
ActivaMenos
	bsf	TecStatus,Menos	;Pone 1 en Menos
	bcf	TecStatus,Mas	;Pone 0 en Mas
	return
;
T1_a_Temp
	movf	HraTime1,W
	movwf	HraTemp		;Copia Hora 1 en Hora Temporal
	movf	MinTime1,W
	movwf	MinTemp		;Copia Minuto1 en Minuto Temporal
	movf	SegTime1,W
	movwf	SegTemp		;Copia Segundo1 en Segundo Temporal
	return
Temp_a_T1
	movf	HraTemp,W
	movwf	HraTime1	;Devuelve Hora temporal a Hora1
	movf	MinTemp,W
	movwf	MinTime1	;Devuelve Minuto temporal a Minuto1
	movf	SegTemp,W
	movwf	SegTime1	;Devuelve Segundo temporal a Segundo1
	return
T2_a_Temp
	movf	HraTime2,W
	movwf	HraTemp		;Copia Hora 2 en Hora Temporal
	movf	MinTime2,W
	movwf	MinTemp		;Copia Minuto2 en Minuto Temporal
	movf	SegTime2,W
	movwf	SegTemp		;Copia Segundo2 en Segundo Temporal
	return
Temp_a_T2
	movf	HraTemp,W
	movwf	HraTime2	;Devuelve Hora temporal a Hora2
	movf	MinTemp,W
	movwf	MinTime2	;Devuelve Minuto temporal a Minuto2
	movf	SegTemp,W
	movwf	SegTime2	;Devuelve Segundo temporal a Segundo2
	return
;
IncHra1
	call	T1_a_Temp	;Copia T1 a temporales
	call	IncHraTemp	;Incrementa las Horas
	call	Temp_a_T1	;Devuelve Temporales a T1
	return
;
IncMin1
	call	T1_a_Temp	;Copia T1 a temporales
	call	IncMinTemp	;Incrementa los minutos
	call	Temp_a_T1	;Devuelve Temporales a T1
	return
;
IncHra2
	call	T2_a_Temp	;Copia T2 a temporales
	call	IncHraTemp	;Incrementa las Horas
	call	Temp_a_T2	;Devuelve Temporales a T2
	return
;
IncMin2
	call	T2_a_Temp	;Copia T2 a temporales
	call	IncMinTemp	;Incrementa los minutos
	call	Temp_a_T2	;Devuelve Temporales a T2
	return
;
DecHra1
	call	T1_a_Temp	;Copia T1 a temporales
	call	DecHraTemp	;Decrementa las Horas
	clrf	SegTemp		;Pone a 0 los segundos
	call	Temp_a_T1	;Devuelve Temporales a T1
	return
DecMin1
	call	T1_a_Temp	;Copia T1 a temporales
	call	DecMinTemp	;Decrementa los minutos
	clrf	SegTemp		;Pone a 0 los segundos
	call	Temp_a_T1	;Devuelve Temporales a T1
	return
;
DecHra2
	call	T2_a_Temp	;Copia T2 a temporales
	call	DecHraTemp	;Decrementa las Horas
	clrf	SegTemp		;Pone a 0 los segundos
	call	Temp_a_T2	;Devuelve Temporales a T2
	return
;
DecMin2
	call	T2_a_Temp	;Copia T2 a temporales
	call	DecMinTemp	;Decrementa los minutos
	clrf	SegTemp		;Pone a 0 los segundos
	call	Temp_a_T2	;Devuelve Temporales a T2
	return
;
;**************************
IncTimer1
	incf	Count1,W	;Incrementa el contador y se guarda en W, Count1 no cambia
	xorlw	.195		;Verifica si Count1 llega a 195
	btfsc	STATUS,Z	;No entonces retorna
	goto	Doitagain	;Si es 195 entonces llama a Doitagain
	incf	Count1,F	;incrementa el contador y lo guarda en Count1
	return
;
Doitagain
	clrf	Count1
	incf	Countagain,W
	xorlw	.2
	btfsc	STATUS,Z
	goto	DoIncTime1
	incf	Countagain
	call	Quitaptos1	;Borra los 2 puntos reloj 1
	return
;
DoIncTime1
	call	Poneptos1	;enciende los 2 puntos reloj1
	clrf	Countagain	;Borra el contador
	call	T1_a_Temp
	call	DoIncTemp	;Llama a rutina de incremento de tiempo con Timer1 como parametro
	call	Temp_a_T1
	return
;
Poneptos1
	movlw	0x02
	movwf	Puntos1
	return
Quitaptos1
	movlw	0x0f
	movwf	Puntos1
	return
;
IncTimer2
	incf	Count2,W	;Incrementa el contador y se guarda en W, Count2 no cambia
	xorlw	.195		;Verifica si Count2 llega a 250
	btfsc	STATUS,Z	;No entonces retorna
	goto	Doitagain1	;Si es 250 entonces llama a DoIncTime2
	incf	Count2,F	;incrementa el contador y lo guarda en Count2
	return
;
Doitagain1
	clrf	Count2
	incf	Countagain1,W
	xorlw	.2
	btfsc	STATUS,Z
	goto	DoIncTime2
	incf	Countagain1
	call	Quitaptos2
	return
;
DoIncTime2
	call 	Poneptos2
	clrf	Countagain1	;Borra el contador
	call	T2_a_Temp
	call	DoIncTemp	;Llama a rutina de incremento de tiempo con Timer2 como parametro
	call	Temp_a_T2
	return
;
Poneptos2
	movlw	0x02
	movwf	Puntos2
	return
;
Quitaptos2
	movlw	0x0f
	movwf	Puntos2
	return
;
DoIncTemp
	incf	SegTemp,W	;Obtiene SegTemp+1 en W
	andlw	0x0f		;Enmascara los 4 bits de mayor peso
	xorlw	0x0a		;es igual a 10?
	btfsc	STATUS,Z	;No entonces salta
	goto	Ind2DTemp	;si es igual a 10 incrementa el segundo Digito
 	incf	SegTemp,F	;Incrementa el 1er digito
	return
;
Ind2DTemp
	swapf	SegTemp,W	;Obtiene la Posicion de mayor peso y la guarda en w
	andlw	0x0f		;Enmascara el digito de menor peso
	addlw	1		;
	movwf	SegTemp		;incrementa SegTemp, El digito de menor peso pasa a 0
	swapf	SegTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x06		;El digito de mayor peso vale 6??
	btfsc	STATUS,Z	;No entonces salta
	goto	Inc3DTemp	;Si es 6 Entonces Incrementa el Tercer Digito
	return
;
Inc3DTemp
	clrf	SegTemp		;Borra los segundos
	Incf	MinTemp,W	;Obtiene el tercer digito
	andlw	0x0f		;Enmascara el cuarto digito
	xorlw	0x0a		;Pregunta si vale 10?
	btfsc	STATUS,Z	;No entonces salta
	goto	Inc4DTemp	;Si vale 10, Incrementa el Cuarto Digito
	incf	MinTemp,F	;Incrementa el tercer digito
	return
;
Inc4DTemp
	swapf	MinTemp,W	;Obtiene la Posicion de mayor peso y la guarda en w
	andlw	0x0f		;Enmascara el digito de menor peso
	addlw	1		;
	movwf	MinTemp		;incrementa MinTemp, El digito de menor peso pasa a 0
	swapf	MinTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x06		;El digito de mayor peso vale 6??
	btfsc	STATUS,Z	;No entonces salta
	goto	IncHora		;Si es 6 Entonces Incrementa la Hora
	return
;
IncHora
	clrf	MinTemp		;Borra los Minutos
	goto	IncHraTemp
	return
;
IncHraTemp
	Incf	HraTemp,W	;Incrementa Hora
	xorlw	0x0a		;Pregunta si vale 10?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora10
	Incf	HraTemp,W	;Incrementa Hora
	xorlw	0x1a		;Pregunta si vale 20?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora20
	Incf	HraTemp,W	;Incrementa Hora
	xorlw	0x24		;Pregunta si vale 24?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora24
	incf	HraTemp,F	;Incrementa la hora
	return
;
Hora10
	movlw	0x10		;carga w con 10	
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
Hora20
	movlw	0x20		;carga w con 20
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
Hora24
	movlw	0x00		;carga w con 00
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
;
IncMinTemp
	clrf	SegTemp		;Borra los segundos
	Incf	MinTemp,W	;Obtiene el tercer digito
	andlw	0x0f		;Enmascara el cuarto digito
	xorlw	0x0a		;Pregunta si vale 10?
	btfsc	STATUS,Z	;No entonces salta
	goto	Inc4MTemp	;Si vale 10, Incrementa el Cuarto Digito
	incf	MinTemp,F	;Incrementa el tercer digito
	return
;
Inc4MTemp
	swapf	MinTemp,W	;Obtiene la Posicion de mayor peso y la guarda en w
	andlw	0x0f		;Enmascara el digito de menor peso
	addlw	1		;
	movwf	MinTemp		;incrementa MinTemp, El digito de menor peso pasa a 0
	swapf	MinTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x06		;El digito de mayor peso vale 6??
	btfsc	STATUS,Z	;No entonces salta
	clrf	MinTemp		;Pone minutos en 0
	return
;
DecTimer1
	incf	Count1,W	;Incrementa el contador y se guarda en W, Count1 no cambia
	xorlw	.195		;Verifica si Count1 llega a 195
	btfsc	STATUS,Z	;No entonces retorna
	goto	Doitagain2	;Si es 250 entonces llama a DoDecTime
	incf	Count1,F	;incrementa el contador y lo guarda en Count1
	return			
;
Doitagain2
	clrf	Count1
	incf	Countagain,W
	xorlw	.2
	btfsc	STATUS,Z
	goto	DoDecTime1
	incf	Countagain
	call	Quitaptos1
	return
;
DoDecTime1
	call	Poneptos1
	clrf	Countagain	;Borra el contador
	call	T1_a_Temp
	call	DoDecTemp	;Llama a rutina de decremento de tiempo con Timer1 como parametro
	call	Temp_a_T1
	return
;
DecTimer2
	incf	Count2,W	;Incrementa el contador y se guarda en W, Count2 no cambia
	xorlw	.195		;Verifica si Count2 llega a 250
	btfsc	STATUS,Z	;No entonces retorna
	goto	Doitagain3	;Si es 250 entonces llama a DoDecTime2
	incf	Count2,F	;incrementa el contador y lo guarda en Count2
	return			
;
Doitagain3
	clrf	Count2
	incf	Countagain1,W
	xorlw	.2
	btfsc	STATUS,Z
	goto	DoDecTime2
	incf	Countagain1
	call	Quitaptos2
	return
;	
DoDecTime2
	call 	Poneptos2
	clrf	Countagain1		;Borra el contador
	call	T2_a_Temp
	call	DoDecTemp	;Llama a rutina de decremento de tiempo con Timer2 como parametro
	call	Temp_a_T2
	return
;
DoDecTemp
	decf	SegTemp,W	;Obtiene SegTemp-1 en W
	andlw	0x0f		;Enmascara los 4 bits de mayor peso
	xorlw	0x0f		;es igual a -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Dec2DTemp	;si es igual a -1 decrementa el segundo Digito
 	decf	SegTemp,F	;Decrementa el 1er digito
	return
;
Dec2DTemp
	swapf	SegTemp,W	;Obtiene la Posicion de mayor peso y la guarda en w
	andlw	0x0f		;Enmascara el digito de menor peso
	movwf	TempD
	decf	TempD,W
	andlw	0x0f		;Pone a 0 los primeros 4 bits de W
	iorlw	0x90		;Coloca 9 en primer digito
	movwf	SegTemp		;Decrementa SegTemp, El digito de menor peso pasa a 9
	swapf	SegTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x9f		;el segundo digito es igual a -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Dec3DTemp	;Si es -1 Entonces Decrementa el Tercer Digito
	return
;
Dec3DTemp
	movlw	0x59		;Carga 59 en W
	movwf	SegTemp		;Coloca los segundos en 59
	decf	MinTemp,W	;Obtiene el tercer digito
	andlw	0x0f		;Enmascara el tercer digito
	xorlw	0x0f		;Pregunta si vale -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Dec4DTemp	;Si vale -1, Decrementa el Cuarto Digito
	decf	MinTemp,F	;Decrementa el tercer digito
	return
;
Dec4DTemp
	swapf	MinTemp,W	;Obtiene el cuarto digito
	andlw	0x0f		;enmascara el tercer digito
	movwf	TempD
	decf	TempD,W		;decrementa el cuarto digito
	andlw	0x0f		;Pone a 0 los primeros 4 bits de W
	iorlw	0x90		;Coloca 9 en primer digito
	movwf	MinTemp		;Decrementa MinTemp, El digito de menor peso pasa a 9
	swapf	MinTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x9f		;el segundo digito es igual a -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	DecHora
	return
;
DecHora
	movlw	0x59		;Carga 59 en W
	movwf	MinTemp		;Coloca los minutos en 59
	goto	DecHraTemp
	return
;
DecHraTemp
	decf	HraTemp,W	;Decrementa Hora
	xorlw	0xff		;Pregunta si vale -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora23
	decf	HraTemp,W	;Decrementa Hora
	xorlw	0x1f		;Pregunta si vale 19?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora19
	decf	HraTemp,W	;Decrementa Hora
	xorlw	0x0f		;Pregunta si vale 9?
	btfsc	STATUS,Z	;No entonces salta
	goto	Hora9
	decf	HraTemp,F	;Decrementa la hora
	return
;
Hora23
	movlw	0x23		;carga w con 23
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
Hora19
	movlw	0x19		;carga w con 19
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
Hora9
	movlw	0x09		;carga w con 09
	movwf	HraTemp		;Pasa W a Hora Temporal
	return
;
DecMinTemp
	decf	MinTemp,W	;Obtiene el tercer digito
	andlw	0x0f		;Enmascara el tercer digito
	xorlw	0x0f		;Pregunta si vale -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Dec4MTemp	;Si vale -1, Decrementa el Cuarto Digito
	decf	MinTemp,F	;Decrementa el tercer digito
	return
;
Dec4MTemp
	swapf	MinTemp,W	;Obtiene el cuarto digito
	andlw	0x0f		;enmascara el tercer digito
	movwf	TempD
	decf	TempD,W		;decrementa el cuarto digito
	andlw	0x0f		;Pone a 0 los primeros 4 bits de W
	iorlw	0x90		;Coloca 9 en primer digito
	movwf	MinTemp		;Decrementa MinTemp, El digito de menor peso pasa a 9
	swapf	MinTemp,F	;coloca el digito de mayor peso en su lugar
	xorlw	0x9f		;el segundo digito es igual a -1?
	btfsc	STATUS,Z	;No entonces salta
	goto	Minuto59	;Pone minutos en 59
	return
;
Minuto59
	movlw	0x59		;Carga 59 en W
	movwf	MinTemp		;Coloca los minutos en 59
	return
;
;SegTemp es segundero, MinTemp es minutero y HraTemp es horario, dichos valores se
;deben mandar al puerto cada 5ms para obtener la visualizacion del reloj. Este proceso
;lo realiza UpdateDisplay
;
UpdateDisplay
	movf	TempC,W		;Guarda el valor actual del puerto B en W
	xorlw	0x0a		;Estaba mostrando los 4 puntos?
	btfsc	STATUS,Z	;No entonces salta
	clrf	TempC		;Pone el selector en 0
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x00		;es el primer digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD1		;Muestra el primer display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x01		;es el Segundo digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD2		;Muestra el Segundo display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x02		;es el Tercer digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD3		;Muestra el Tercer display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x03		;es el Cuarto digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD4		;Muestra el Cuarto display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x04		;es el Quinto digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD5		;Muestra el Quinto display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x05		;es el Sexto digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD6		;Muestra el Sexto display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x06		;es el Septimo digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD7		;Muestra el Septimo display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x07		;es el Septimo digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowD8		;Muestra el Septimo display
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x08		;es el Septimo digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowPuntos1	;Muestra puntos J1
	movf	TempC,W		;Guarda TemC en W
	xorlw	0x09		;es el Septimo digito?
	btfsc	STATUS,Z	;No entonces salta
	goto	ShowPuntos2	;Muestra puntos J2
	
	
;muestra los 2 puntos J1
ShowPuntos1
	movf	Puntos1,W	;Guarda puntos en w
	andlw	0x0f		;mayor peso en puntos
	movwf	TempD		;TempD tiene el valor de puntos
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x05		;Extrae los bits de Pausa y J2
	xorlw	0x05		;Setup a J2?
	btfsc	STATUS,Z	;No entonces salta
	goto	DelPuntos1	;llama rutina de Borrar Display
	goto	Displayout	;muestra los puntos
	
ShowPuntos2
	movf	Puntos2,W	;Guarda puntos en w
	andlw	0x0f		;mayor peso en puntos
	movwf	TempD		;TempD tiene el valor de puntos
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x03		;Extrae los bits de Pausa y J1
	xorlw	0x03		;Setup a J1?
	btfsc	STATUS,Z	;No entonces salta
	goto	DelPuntos2	;llama rutina de Borrar Display
	goto	Displayout	;muestra los puntos

;muestra 8 digito
ShowD8	
	call	HraD8		;Muestra horas
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ2
;
	movf	HraTime2,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	MinD8		;Muestra segundos
	goto 	DisplayJ2	;Verifica si muestra o no dependiendo de Pausa y J1
;
HraD8
	Swapf	HraTime2,W	;Guarda horario en w
	andlw	0x0f		;Borra las unidades de hora
	movwf	TempD		;TempD tiene el valor de las unidades de hora
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
MinD8
	Swapf	MinTime2,W	;Guarda minutero en w
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor de las unidades de minuto
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD1
	call	MinD1		;Muestra minutos
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ1
	movf	HraTime1,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	SegD1		;Muestra segundos
	goto	DisplayJ1	;Verifica si muestra o no dependiendo de Pausa y J2
;
MinD1
	movf	MinTime1,W	;Guarda Minutero en w
	andlw	0x0f		;Borra las decenas de minuto
	movwf	TempD		;TempD tiene el valor del minutero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
SegD1
	movf	SegTime1,W	;Guarda Segundero en w
	andlw	0x0f		;Borra las decenas de segundo
	movwf	TempD		;TempD tiene el valor del Segundero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
ShowD2
	call	MinD2		;Muestra minutos
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ1
	movf	HraTime1,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	SegD2		;Muestra segundos
	goto	DisplayJ1	;Verifica si muestra o no dependiendo de Pausa y J2
;
MinD2
	Swapf	MinTime1,W	;Guarda minutero
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor del Minutero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
SegD2
	Swapf	SegTime1,W	;Guarda segundero
	andlw	0x0f		;Borra las unidades de segundo
	movwf	TempD		;TempD tiene el valor del Segundero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD3
	call	HraD3		;Muestra horas
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ1
	movf	HraTime1,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	MinD3		;Muestra minutos
	goto	DisplayJ1	;Verifica si muestra o no dependiendo de Pausa y J2
;
HraD3
	movf	HraTime1,W	;Guarda horario en w
	andlw	0x0f		;Borra las unidades de hora
	movwf	TempD		;TempD tiene el valor de las unidades de hora
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
MinD3
	movf	MinTime1,W	;Guarda minutero en w
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor de las unidades de minuto
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD4
	call	HraD4		;Muestra horas
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ1
	movf	HraTime1,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	MinD4		;Muestra minutos
	goto	DisplayJ1	;Verifica si muestra o no dependiendo de Pausa y J2
;
HraD4
	Swapf	HraTime1,W	;Guarda horario en w
	andlw	0x0f		;Borra las unidades de hora
	movwf	TempD		;TempD tiene el valor de las unidades de hora
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
MinD4
	Swapf	MinTime1,W	;Guarda minutero en w
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor de las unidades de minuto
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD5
	call	MinD5		;Muestra minutos
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ2
	movf	HraTime2,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	SegD5		;Muestra segundos
	goto 	DisplayJ2	;Verifica si muestra o no dependiendo de Pausa y J1
;
MinD5
	movf	MinTime2,W	;Guarda Minutero en w
	andlw	0x0f		;Borra las decenas de minuto
	movwf	TempD		;TempD tiene el valor del minutero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
SegD5
	movf	SegTime2,W	;Guarda Segundero en w
	andlw	0x0f		;Borra las decenas de minuto
	movwf	TempD		;TempD tiene el valor del Segundero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD6
	call	MinD6		;Muestra minutos
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ2
	movf	HraTime2,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	SegD6		;Muestra segundos
	goto 	DisplayJ2	;Verifica si muestra o no dependiendo de Pausa y J1
;
MinD6
	Swapf	MinTime2,W	;Guarda minutero
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor del minutero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
SegD6
	Swapf	SegTime2,W	;Guarda segundero
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor del Segundero
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
ShowD7
	call	HraD7		;Muestra horas
	btfsc	TecStatus,Pausa	;Si Pausa esta en cero salta
	goto 	DisplayJ2
	movf	HraTime2,W	;Guarda Hora en w
	xorlw	0x00		;La Hora vale 0?
	btfsc	STATUS,Z	;No entonces salta
	call	MinD7		;Muestra segundos
	goto 	DisplayJ2	;Verifica si muestra o no dependiendo de Pausa y J1
;
HraD7
	movf	HraTime2,W	;Guarda horario en w
	andlw	0x0f		;Borra las unidades de hora
	movwf	TempD		;TempD tiene el valor de las unidades de hora
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
MinD7
	movf	MinTime2,W	;Guarda minutero en w
	andlw	0x0f		;Borra las unidades de minuto
	movwf	TempD		;TempD tiene el valor de las unidades de minuto
	swapf	TempC,W		;Guarda tempC en w
	iorwf	TempD,F		;Guarda en tempD el valor a sacar por el puerto B
	return
;
DisplayJ1
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x05		;Extrae los bits de Pausa y J2
	xorlw	0x05		;Setup a J2?
	btfsc	STATUS,Z	;No entonces salta
	goto	DelDisplay	;llama rutina de Borrar Display
	goto 	Displayout	;Muestra el digito
;
DisplayJ2
	movf	TecStatus,W	;Guarda el valor actual de las Teclas en W
	andlw	0x03		;Extrae los bits de Pausa y J1
	xorlw	0x03		;Setup a J1?
	btfsc	STATUS,Z	;No entonces salta
	goto	DelDisplay	;llama rutina de Borrar Display
	goto 	Displayout	;Muestra el digito
;
DelDisplay
	movf	TempD,W		;carga TempD en W
	iorlw	0x0F		;Coloca F en el Dato
	movwf	PORTB		;Carga el puerto con el valor a visualizar
	incf	TempC,F		;Incrementa TempC para habilitar siguiente display
	return
;
DelPuntos1
	movf	TempD,W		;carga TempD en W
	andlw	0x8f		;Coloca c en el Dato
	movwf	PORTB		;Carga el puerto con el valor a visualizar
	incf	TempC,F		;Incrementa TempC para habilitar siguiente display
	return
;	
DelPuntos2
	movf	TempD,W		;carga TempD en W
	andlw	0x9f		;Coloca 3 en el Dato
	movwf	PORTB		;Carga el puerto con el valor a visualizar
	incf	TempC,F		;Incrementa TempC para habilitar siguiente display
	return
;
Displayout
	movf	TempD,W		;carga TempD en W
	movwf	PORTB		;Carga el puerto con el valor a visualizar
	incf	TempC,F		;Incrementa TempC para habilitar siguiente display
	return
;
	end