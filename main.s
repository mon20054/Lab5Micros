
; Archivo:	main.s
; Dispositivo:	PIC16F887
; Autor:	Javier Monzón 20054
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Contador de 8 bits en el puerto B
; Hardware:	LEDs en el puerto B y push buttons en el puerto A
;		Displays de 7 segmentos en el puerto C
;
; Creado:	21 febrero 2022
; Última modificación: 21 febrero 2022

PROCESSOR 16F887
#include <xc.inc>
    
; Configuration word 1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscilador interno sin salidas
  CONFIG  WDTE = OFF            ; WDT disabled (reinicio repetitivo del PIC)
  CONFIG  PWRTE = OFF           ; PWRT enabled (espera de 72ms al iniciar)
  CONFIG  MCLRE = OFF           ; El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              ; Sin protección de código 
  CONFIG  CPD = OFF             ; Sin protección de datos
  
  CONFIG  BOREN = OFF           ; Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            ; Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           ; Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF             ; Programación en bajo voltaje permitida
  
; Configuration word 2
  CONFIG  BOR4V = BOR40V        ; Reinicio abajo de 4V 
  CONFIG  WRT = OFF             ; Protección de autoescritura por el programa desactivada 
    
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    wtemp:		DS  1
    status_temp:	DS  1
  
PSECT udata_bank0		; Variables almacenadas en el banco 0
  cont_1:	DS  1
  banderas:	DS  1
  valor:	DS  1
  unidades:	DS  1
  decenas:	DS  1
  centenas:	DS  1
  resta:	DS  1
  veces_u:	DS  1
  veces_d:	DS  1
  veces_c:	DS  1
  diez:		DS  1
  cien:		DS  1
  uno:		DS  1
  display:	DS  3
  
PSECT resVect, class = CODE, abs, delta = 2
 ;-------------- vector reset ---------------
 ORG 00h			; Posición 00h para el reset
 resVect:
    goto main

PSECT intVect, class = CODE, abs, delta = 2
ORG 004h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
 
push:
    movwf   wtemp		; Se guarda W en el registro temporal
    swapf   STATUS, W		
    movwf   status_temp		; Se guarda STATUS en el registro temporal
    
isr:
    banksel INTCON
    btfsc   T0IF		; Ver si bandera de TMR0 se encendió
    call    t0
    call    mostrar_valores
    
pop:
    swapf   status_temp, W	
    movwf   STATUS		; Se recupera el valor de STATUS
    swapf   wtemp, F
    swapf   wtemp, W		; Se recupera el valor de W
    retfie      
    
PSECT code,  delta = 2, abs
ORG 100h
 
main:
    call    config_IO		; Configuración de I/O
    call    config_clk		; Configuración de reloj
    call    config_tmr0
    call    config_int		; Configuración de interrupciones
    
loop:
    call    B1
    call    B2
    movf    cont_1, 0
    movwf   PORTB
    
    ; Convertir a decimal 
    clrf    veces_u
    clrf    veces_d
    clrf    veces_c
    movf    cont_1, 0
    movwf   valor
    
    movf    cien,   0
    subwf   valor,  1
    incf    veces_c,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_centenas

    movf    diez,   0
    subwf   valor,  1
    incf    veces_d,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas

    movf    uno,    0
    subwf   valor,  1
    incf    veces_u,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades
   
    call    set_display
    goto    loop
    
;--------------- Subrutinas ------------------
config_IO:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH	    ; I/O digitales
    banksel TRISA
    bsf	    TRISA,  0	    ; RA0 como entrada
    bsf	    TRISA,  1	    ; RA1 como entrada
    clrf    TRISB	    ; Puerto B como salida
    clrf    TRISC	    ; Puerto C como salida
    clrf    TRISD	    ; Puerto D como salida
    banksel PORTA
    clrf    PORTA
    clrf    PORTB	    
    clrf    PORTC
    clrf    PORTD
    movlw   0x00
    movwf   cont_1	    ; Contador siempre inicia en 0
    movlw   0x00
    movwf   unidades
    movlw   0x00
    movwf   decenas
    movlw   0x00
    movwf   centenas
    movlw   0x00
    movwf   mod10
    movlw   0x00
    movwf   resta
    movlw   0x00
    movwf   veces_u
    movlw   0x00
    movwf   veces_d
    movlw   0x0A
    movwf   diez
    movlw   0x64
    movwf   cien
    movlw   0x01
    movwf   uno
    return
 
config_clk:
    banksel OSCCON	    ; cambiamos a banco de OSCCON
    bsf	    OSCCON,	 0  ; SCS -> 1, Usamos reloj interno
    bsf	    OSCCON,	 6
    bcf	    OSCCON,	 5
    bcf	    OSCCON,	 4  ; IRCF<2:0> -> 100 1MHz
    return
    
config_tmr0:
    banksel OPTION_REG	    ; Cambiamos a banco de OPTION_REG
    bcf	    OPTION_REG, 5   ; T0CS = 0 --> TIMER0 como temporizador 
    bcf	    OPTION_REG, 3   ; Prescaler a TIMER0
    bsf	    OPTION_REG, 2   ; PS2
    bsf	    OPTION_REG, 1   ; PS1
    bsf	    OPTION_REG, 0   ; PS0 Prescaler de 1 : 256
    banksel TMR0	    ; Cambiamos a banco 0 de TIMER0
    movlw   252		    ; Cargamos el valor 246 a W
    movwf   TMR0	    ; Cargamos el valor de W a TIMER0 para 4.44mS de delay
    bcf	    T0IF	    ; Borramos la bandera de interrupcion
    return  
    
config_int:
    banksel INTCON
    bsf	    GIE		    ; Habilitamos interrupciones
    bsf	    T0IE	    ; Habilitamos interrupcion TMR0
    bcf	    T0IF	    ; Limpiamos bandera de TMR0
    return
    
reset_tmr0:
    banksel TMR0	    ; cambiamos de banco
    movlw   252
    movwf   TMR0	    ; delay 4.44mS
    bcf	    T0IF
    return
    
t0:
    call    reset_tmr0
    incf    PORTC
    return
    
B1:
    btfsc   PORTA,  0
    return
    call    antirebotes1
    return
    
B2:
    btfsc   PORTA,  1
    return
    call    antirebotes2
    return
    
antirebotes1:
    btfss   PORTA,  0	
    goto    $-1
    incf    cont_1
    return
    
antirebotes2:
    btfss   PORTA,  1
    goto    $-1
    decf    cont_1
    return

set_display:
    movf    unidades,	w 
    call    tabla
    movwf   display
    
    movf    decenas,	W
    call    tabla
    movwf   display+1
    
    movf    centenas,	W
    call    tabla
    movwf   display+2
    return
    
mostrar_valores:
    clrf    PORTD
    btfsc   banderas,	0
    goto    display_1
    btfsc   banderas,	1
    goto    display_2
    goto    display_0
    
    display_0:			    ; Display de centenas
	movf    display+2,    W
	movwf   PORTC
	bsf	PORTD,	    0
	bsf	banderas,   0
return

    display_1:			    ; Display de decenas
	movf    display+1,  W
	movwf   PORTC
	bsf	PORTD,	    1
	bcf	banderas,   0
	bsf	banderas,   1
return
	
    display_2:			    ; Display de unidades
	movf	display,   W
	movwf	PORTC
	bsf	PORTD,	    2
	bcf	banderas,   0
	bcf	banderas,   1
return
	
check_centenas:
    decf    veces_c,	1
    movf    cien,   0
    addwf   valor,  1
    movf    veces_c,	0
    movwf   centenas
    return
    
check_decenas:
    decf    veces_d,	1
    movf    diez,   0
    addwf   valor,  1
    movf    veces_d,	0
    movwf   decenas
    return
    
check_unidades:
    decf    veces_u,	1
    movf    uno,    0
    addwf   valor,  1
    movf    veces_u,	0
    movwf   unidades
    return
	
org 200h
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 1
    andlw   0x0F
    addwf   PCL, 1		; Se suma el offset al PC y se almacena en dicho registro
    retlw   0b11011101		; Valor para 0 en display de 7 segmentos
    retlw   0b01010000		; Valor para 1 en display de 7 segmentos
    retlw   0b11001110		; Valor para 2 en display de 7 segmentos
    retlw   0b11011010		; Valor para 3 en display de 7 segmentos
    retlw   0b01010011		; Valor para 4 en display de 7 segmentos
    retlw   0b10011011		; Valor para 5 en display de 7 segmentos 
    retlw   0b10011111		; Valor para 6 en display de 7 segmentos 
    retlw   0b11010000		; Valor para 7 en display de 7 segmentos 
    retlw   0b11011111		; Valor para 8 en display de 7 segmentos
    retlw   0b11010011		; Valor para 9 en display de 7 segmentos 
    retlw   0b11010111		; Valor para A en display de 7 segmentos
    retlw   0b00011111		; Valor para B en display de 7 segmentos
    retlw   0b10001101		; Valor para C en display de 7 segmentos
    retlw   0b01011110		; Valor para D en display de 7 segmentos
    retlw   0b10001111		; Valor para E en display de 7 segmentos 
    retlw   0b10000111		; Valor para F en display de 7 segmentos
    
END



