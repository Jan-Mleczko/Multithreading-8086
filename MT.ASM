; Zarz�dca wielow�tkowo�ci dla 8086
; Autor:  Jan Mleczko
; Data:   sierpie� 2024
; Wersja: 1.0

; Ca�o�� dzia�a jako jeden program pod DOS-em.
; Kod wszystkich w�tk�w wraz z samym zarz�dc� musi mie�ci� si� w jednym
; segmencie, jako �e stosowane s� bliskie skoki i wywo�ania oraz 16-bitowe
; adresy bez segmentu.
; W celu umo�liwienia prze��czania mi�dzy w�tkami ka�dy w�tek musi co jaki�
; czas wywo�ywa� procedur� "daj czas innym w�tkom" (MTPAUSE).
; Najlepiej robi� to podczas p�tli oczekuj�cych na co�.
; Zarz�dca nie zapewnia osobnego stosu dla ka�dego w�tku, a wi�c nale�y by�
; ostro�nym z jego wykorzystywaniem.
; Dok�adniej rzecz ujmuj�c, w�tek nie powinien nic trzyma� na stosie w chwili
; wstrzymania na rzecz innych w�tk�w.

; Udost�pniany interfejs:
; CALL MTSTART - Uruchomienie zarz�dcy i wej�cie w prac� wielow�tkow�.
;                AX wskazuje na procedur� "w�tku pierwotnego" b�d�cego
;                pocz�tkowo jedynym w�tkiem.

; Dalsze procedury interfejsu s� przeznaczone dla w�tk�w dzia�aj�cych podczas
; pracy wielow�tkowej.

; CALL MTPAUSE - Wstrzymanie dzia�ania bie��cego w�tku w celu pozwolenia na
;                prac� pozosta�ych uruchomionych w�tk�w.
; JMP MTKILL   - Zako�czenie bie��cego w�tku.
; CALL MTFORK  - Uruchomienie nowego w�tku spod adresu podanego w AX.
;                Nie powoduje to natychmiastowego przej�cia do nowego w�tku.
;                Wszystkie rejestry sprzed tego wywo�ania s� zachowywane.
; JMP MTSTOP   - Zako�czenie pracy wielow�tkowej i zwr�cenie sterowania do
;                miejsca wywo�ania MTSTART.
;                Odbywa si� to r�wnie� samoczynnie w razie zako�czenia si�
;                wszystkich w�tk�w.

ORG $100

;=======================================
; Program g��wny

	; Uruchom zarz�dc� wielow�tkowo�ci i pierwszy w�tek.
	MOV	AX, THR1
	CALL	MTSTART
	; Praca wielow�tkowa zosta�a zako�czona.
	
	; Wr�� do DOS-u.
	MOV	AX, $4C00
	INT	$21


;=======================================
; Zarz�dca wielow�tkowio�ci

ACCTHREADS	EQU 10 ; Dopuszczalna ilo�� w�tk�w.

;---------------------------------------

MTSTART:
	; Rozpocz�cie pracy wielow�tkowej i uruchomienie "w�tku pierwotnego"
	; AX - adres pierwszego w�tku.
	
	; Zachowaj adres powrotu.
	POP	WORD [MTRETURN]
	
	; Wpisz w�tek pierwotny jako jedyny element tablicy w�tk�w,
	; uczy� go w�tkiem bie��cym i przejd� do niego.
	
	MOV	WORD [NXTHREAD], THTABLE+2
	MOV	WORD [THTABLE], AX
	MOV	WORD [CTHREAD], THTABLE
	
	JMP	AX

;---------------------------------------

MTSTOP:
	; Koniec pracy wielow�tkowej.
	JMP	WORD [MTRETURN]

;---------------------------------------

MTPAUSE:
	; Wstrzymanie dzia�ania z perspektywy w�tku bie��cego, tj. zmiana 
	; w�tku na kolejny w tablicy w�tk�w.

	; Je�li jest tylko jeden w�tek, nic nie r�b.
	CMP	WORD [NXTHREAD], THTABLE+2
	JA	MTMANY
	RET

MTMANY:
	; Istniej� conajmniej dwa w�tki.

	; Zapisz, gdzie bie��cy w�tek przerwa� prac� wywo�uj�c MTPAUSE.
	POP	AX
	MOV	DI, WORD [CTHREAD]
	MOV	WORD [DI], AX
	
	; Wybierz w�tek do przekazania sterowania.
	; B�dzie nim nast�pny w�tek w tablicy w�tk�w, lub, je�eli mamy do
	; czynienia z ostatnim w�tkiem w tablicy - w�tek na miejscu pierwszym.
	
	; Przesu� DI jeden wpis na prawo.
	ADD	DI, 2
	; Sprawd�, czy jeste�my ju� poza u�ywan� cz�ci� tablicy.
	CMP	DI, WORD [NXTHREAD]
	JB	MTSELECTED
	
	; To by� ostatni w�tek - "zawr��" do pierwszego.
	MOV	DI, THTABLE

MTSELECTED:
	; DI wskazuje na nowy bie��cy w�tek.
	; Zapisz, �e jest on w�tkiem bie��cym i przejd� do niego.
	
	MOV	WORD [CTHREAD], DI
	
	; Nale�y pami�ta�, �e DI nie wskazuje bezpo�rednio adresu do
	; kontynuacji w�tku, a wpis w tablicy w�tk�w, kt�ry to stanowi w�a�nie
	; ten adres.
	MOV	AX, WORD [DI]
	; Teraz - w AX - mamy w�a�ciwy adres pobrany z tablicy.
	JMP	AX

;---------------------------------------

MTFORK:
	PUSH	DI

	; Dopisz nowy w�tek (z AX) do tablicy w�tk�w.
	MOV	DI, WORD [NXTHREAD]
	MOV	WORD [DI], AX
	ADD	DI, 2
	MOV	WORD [NXTHREAD], DI
	
	POP	DI
	RET

;---------------------------------------

MTKILL:
	; Zako�czenie bie��cego w�tku.

	; Usu� bie��cy w�tek z tablicy w�tk�w przesuwaj�c o jedno miejsce w
	; lewo wpisy le��ce za usuwanym wpisem.
	MOV	DI, WORD [CTHREAD]
	MOV	SI, DI
MTSHIFT:
	ADD	SI, 2
	CMP	SI, WORD [NXTHREAD]
	JNB	MTSHDONE
	
	MOV	AX, WORD [SI]
	MOV	WORD [DI], AX
	
	MOV	DI, SI
	JMP	MTSHIFT
MTSHDONE:
	MOV	WORD [NXTHREAD], DI
	
	; Sprawd�, czy pozosta�y jakiekolwiek w�tki - je�eli nie, zako�cz
	; prac� wielow�tkow�.
	CMP	WORD [NXTHREAD], THTABLE
	JE	MTSTOP
	
	; Teraz, gdy bie��cy w�tek zosta� usuni�ty, trzeba przej�� do jakiego�
	; innego w�tku.
	; Przejd� do w�tku pierwszego w tablicy (bo tak).
	MOV	AX, WORD [THTABLE]
	MOV	WORD [CTHREAD], THTABLE
	JMP	AX

;---------------------------------------
; Dane zarz�dcy wielow�tkowo�ci

MTRETURN:
	DW 0
	; Adres powrotu dla ca�ego zarz�dcy.

THTABLE:
	TIMES ACCTHREADS DW 0
	; "Tablica w�tk�w"
	; Dla ka�dego w�tku zawiera ona adres, od kt�rego nale�y wznowi�
	; wykonywanie danego w�tku.

CTHREAD:
	DW 0
	; Wska�nik na bie��cy w�tek w tablicy w�tk�w.

NXTHREAD:
	DW 0
	; Wska�nik na miejsce dla nowego w�tku w tablicy w�tk�w.


;=======================================
; W�tki

; Testem dla zarz�dcy wielow�tkowo�ci b�dzie uruchomienie trzech w�tk�w
; wy�wietlaj�cych ci�g odpowiednio liter A, B i C pracuj�c na zmian�.
; W�tek nr 1 jest odpowiedzialny za uruchomienie trzech pozosta�ych
; "w�a�ciwych" w�tk�w.
; Kod poni�ej, tak samo jak program g��wny, nie jest cz�ci� samego zarz�dcy
; wielow�tkowo�ci, a jedynie przyk�adowym jego u�yciem.

THR1:
	; W�tek 1.
	; Uruchamia w�tki 2, 3 i 4 po czym zaka�cza si�.
	
	MOV	AX, THR2
	CALL	MTFORK
	MOV	AX, THR3
	CALL	MTFORK
	MOV	AX, THR4
	CALL	MTFORK
	
	JMP	MTKILL

;---------------------------------------

THR2:
	; W�tek 2. Wy�wietla 10 razy liter� A.
	
	MOV	CL, 10
T2LOOP:
	MOV	BYTE [T2COUNT], CL

	; Wy�wietl znak za po�rednictwem DOS-u.
	MOV	AH, 2
	MOV	DL, 'A'
	INT	$21
	
	; Pozw�l na zadzia�anie innych w�tk�w.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T2COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T2LOOP
	
	JMP	MTKILL

T2COUNT:
	; Licznik powt�rze� przechowywany w pami�ci.
	; Wa�ne, aby by� osobny dla ka�dego z w�tk�w.
	DB 0

;---------------------------------------

THR3:
	; W�tek 3. Wy�wietla 15 razy liter� B.
	
	MOV	CL, 15
T3LOOP:
	MOV	BYTE [T3COUNT], CL

	MOV	AH, 2
	MOV	DL, 'B'
	INT	$21
	
	; Pozw�l na dzia�anie innych w�tk�w.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T3COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T3LOOP
	
	JMP	MTKILL

T3COUNT:
	; Licznik powt�rze� przechowywany w pami�ci.
	; Wa�ne, aby by� osobny dla ka�dego z w�tk�w.
	DB 0

;---------------------------------------

THR4:
	; W�tek 4. Wy�wietla 20 razy liter� C.
	
	MOV	CL, 20
T4LOOP:
	MOV	BYTE [T4COUNT], CL

	MOV	AH, 2
	MOV	DL, 'C'
	INT	$21
	
	; Pozw�l na dzia�anie innych w�tk�w.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T4COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T4LOOP
	
	JMP	MTKILL

T4COUNT:
	; Licznik powt�rze� przechowywany w pami�ci.
	; Wa�ne, aby by� osobny dla ka�dego z w�tk�w.
	DB 0