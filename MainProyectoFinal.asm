; Regina Franco Camacho
; Proyecto Final: Simulador Sistema de Seguridad

    
.equ DireccionSRAM = 0x200  ; Dirección donde empieza la SRAM del ATMEGA 2560
.equ led_Azul = 0x10
.equ led_Rojo = 0x08
.equ led_Verde = 0x04
    
.org 0

rjmp setup
    
setup:
    ; Configuración de puertos
    ldi r16, 0x1C	; 0x1C = 0b 0001_1100 LEDS (G, R, B)
    out DDRA, r16	; pinMode(Puerto A, OUTPUT)
    
    ldi r16, 0x00	; Los 0's son de input y los 1's de output
    out DDRC, r16	; pinMode(PuertoC, INPUT) Botón
    
    ldi r16, 0x07	; 0x07 = 0b 0000_0111
    out DDRF, r16	; Se declaran las columnas como entrada y las filas como salidas
    
    ; Almacenar clave en SRAM
    ldi ZL, low(0x200)		; Cargar parte baja en puntero ZL
    ldi ZH, high(0x200)	; Cargar parte alta en puntero ZH
    
    ; La clave será "1, 2, 3, 4"
    ldi r16, 0x14	; 0x14 = 0001_0100 = Máscara del 1 decimal
    st Z+, r16		; Almacenar en 0x0100 e incrementar Z	
    
    ldi r16, 0x12	; 0x12 = 0001_0010 = Máscara del 2 decimal
    st Z+, r16		; Almacenar en 0x0101 e incrementar Z
    
    ldi r16, 0x11	; 0x11 = 0001_0001 = Máscara del 3 decimal
    st Z+, r16		; Almacenar en 0x0102 e incrementar Z
    
    ldi r16, 0x24	; 0x24 = 0010_0100 = Máscara del 4 decimal
    st Z, r16		; Almacenar en 0x0103 e incrementar Z
    
loop: 
    ldi r16, 0x00	;
    out PORTA, r16	; Apagar LEDs
    
    ldi r17, 0x01	; 0x01 = 0b 0000_0001 que significa que el botón se activó
    in r16, PINC	; Espera que se active el btn
    and r16, r17	; Corrobora la máscara con el input
    cpi r16, 1		; si r16 = 1 -> se activó el botón
    brne alertaActiva	; "Saltar si no es igual" 
    rjmp loop		; si FALSE, vuelve a empezar

alertaActiva: 
    ldi r22, 0x00	; Resetear el contador
    ; Usar el puntero x
    ldi XL, low(0x210)	; Cargar parte baja en puntero XL
    ldi XH, high(0x210)	; Cargar parte alta en puntero XH
	 
    ldi r16, led_Azul	; 0x10 = 0b 0001_0000 LED Azul (Buzzer)
    out PORTA, r16	; Prende el lED Azul
    call leerTeclado	; Llama a leer teclado
    rjmp loop
    
; Funciones sobre leer teclado
    leerTeclado:
	; Las columnas se mantendran en XL
	ldi r16, 0x04	; 0x04 = 0000_0100 -> Encender primer columna
	out PORTF, r16 
	mov r25, r16	; Mover valor a XL
	rcall detectarPulso
	rcall retardo

	ldi r16, 0x02	; 0x04 = 0000_0010 -> Encender segunda columna
	out PORTF, r16 
	mov r25, r16	; Mover valor a XL
	rcall detectarPulso
	rcall retardo
	
	ldi r16, 0x01	; 0x04 = 0000_0001 -> Encender tercera columna
	out PORTF, r16 
	mov r25, r16	; Mover valor a XL
	rcall detectarPulso
	rcall retardo

	rjmp leerTeclado
    
    detectarPulso:
	cpi r26, 0x14	; Comprueba XL con 0x14
	breq comprobarClave
    
	in r17, PINF	; Leer el puerto F
	andi r17, 0xF0	; Obliga a que los LSB sean 0000	
	
	cpi r17, 0
	brne leerFilas	; Si no es igual, se pulso una tecla y se leerá cual
	ret		; Si no se pulsa nada, regresa a leerTeclado
	
    ; Las filas usarán XH
    leerFilas:
	ldi r19, 0x00
	out PORTF, r19	; Poner filas a 0
    
	mov r18, r17 	; Realizo una copia de r17
	andi r18, 0x10	; 0x10 = 0001_0000 (FilaA). Compara puerto c/n máscara
	cpi r18, 0	
	brne guardarDatos	
	
	mov r18, r17 	; Realizo una copia de r17	
	andi r18, 0x20	; 0x20 = 0010_0000 (FilaB). 	 
	cpi r18, 0
	brne guardarDatos
	
	mov r18, r17 ;Realizo una copia de r17
	andi r17,  0x40	; 0x40 = 0100_0000 (FilaC).
	cpi r18, 0
	brne guardarDatos
	
	mov r18, r17
	andi r17, 0x80	; 0x80 = 1000_0000 (FilaD). 
	cpi r18, 0
	brne guardarDatos

	ret
 
    guardarDatos:
    add r17, r25	; Sumar fila con columna
    st X+, r17		; Almacenar en 0x0110 e incrementar X
    
    ; Parpadeo de LED azul cada que se pulse una tecla:
    ldi r16, 0x00	
    out PORTA, r16	; Apaga el lED Azul
    call retardo
    call retardo
    call retardo 
    ldi r16, led_Azul	; 0x10 = 0b 0001_0000 LED Azul (Buzzer)
    out PORTA, r16	; Prende el lED Azul
    
    rcall retardo
    rjmp detectarPulso
    
    
; Funciones sobre validar clave
; En Z está la clave y en X el intento
    comprobarClave:
    ; Resetear la dirección de punteros
    ldi ZL, low(0x200)	    ; Resetar ZL
    ldi ZH, high(0x200)    ;  Resetar ZH
    
    ldi XL, low(0x210)	    ; Resetar XL
    ldi XH, high(0x210)    ;  Resetar XH
    
    ; Valor 1
    ld r16, Z+	    ; Cargar en r16 a lo que apunte Z
    ld r17, X+	    ; Cargar en r17 a lo que apunte X
    cp r16, r17   
    brne claveIncorrecta    ; Saltar si no coincide
    
    ; Valor 2
    ld r16, Z+	    ; Cargar en r16 a lo que apunte Z
    ld r17, X+	    ; Cargar en r17 a lo que apunte X
    cp r16, r17      
    brne claveIncorrecta    ; Saltar si no coincide
    
    ; Valor 3
    ld r16, Z+	    ; Cargar en r16 a lo que apunte Z
    ld r17, X+	    ; Cargar en r17 a lo que apunte X
    cp r16, r17         
    brne claveIncorrecta    ; Saltar si no coincide
    
    ; Valor 4
    ld r16, Z	    ; Cargar en r16 a lo que apunte Z
    ld r17, X	    ; Cargar en r17 a lo que apunte X
    cp r16, r17      
    brne claveIncorrecta    ; Saltar si no coincide
    
    rjmp claveCorrecta	    ; Si llegó hasta aquí, la clave es correcta
    
    claveCorrecta: 
	ldi r16, led_Verde	; 0x04 = 0000_0100 LED Verde
	out PORTA, r16	; Prende LED Verde
	rcall retardo	
	ldi r16, 0x00	; 
	out PORTA, r16	; Apaga todos los LED
	rcall retardo
	
	rjmp loop	; Regresa al loop principal


    claveIncorrecta:
	ldi r16, led_Rojo	; 0x8 = 0000_1000 LED Rojo
	out PORTA, r16	; Prende LED Rojo
	rcall retardo	
	ldi r16, 0x10	; 0x10 = 0b 0001_0000 LED Azul 
	out PORTA, r16	; Deja prendido sólo el LED Azul
	
	ldi XL, low(0x210)  ; Resetear puntero
	ldi XH, high(0x210)
	rjmp leerTeclado

    
retardo:	
    ldi  r20, 82
    ldi  r21, 43
    ldi  r22, 0
L1: dec  r22
    brne L1
    dec  r21
    brne L1
    lpm
    nop
    ret	    
     