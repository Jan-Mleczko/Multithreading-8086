; Zarz¹dca wielow¹tkowoœci dla 8086
; Autor:  Jan Mleczko
; Data:   sierpieñ 2024
; Wersja: 1.0

; Ca³oœæ dzia³a jako jeden program pod DOS-em.
; Kod wszystkich w¹tków wraz z samym zarz¹dc¹ musi mieœciæ siê w jednym
; segmencie, jako ¿e stosowane s¹ bliskie skoki i wywo³ania oraz 16-bitowe
; adresy bez segmentu.
; W celu umo¿liwienia prze³¹czania miêdzy w¹tkami ka¿dy w¹tek musi co jakiœ
; czas wywo³ywaæ procedurê "daj czas innym w¹tkom" (MTPAUSE).
; Najlepiej robiæ to podczas pêtli oczekuj¹cych na coœ.
; Zarz¹dca nie zapewnia osobnego stosu dla ka¿dego w¹tku, a wiêc nale¿y byæ
; ostro¿nym z jego wykorzystywaniem.
; Dok³adniej rzecz ujmuj¹c, w¹tek nie powinien nic trzymaæ na stosie w chwili
; wstrzymania na rzecz innych w¹tków.

; Udostêpniany interfejs:
; CALL MTSTART - Uruchomienie zarz¹dcy i wejœcie w pracê wielow¹tkow¹.
;                AX wskazuje na procedurê "w¹tku pierwotnego" bêd¹cego
;                pocz¹tkowo jedynym w¹tkiem.

; Dalsze procedury interfejsu s¹ przeznaczone dla w¹tków dzia³aj¹cych podczas
; pracy wielow¹tkowej.

; CALL MTPAUSE - Wstrzymanie dzia³ania bie¿¹cego w¹tku w celu pozwolenia na
;                pracê pozosta³ych uruchomionych w¹tków.
; JMP MTKILL   - Zakoñczenie bie¿¹cego w¹tku.
; CALL MTFORK  - Uruchomienie nowego w¹tku spod adresu podanego w AX.
;                Nie powoduje to natychmiastowego przejœcia do nowego w¹tku.
;                Wszystkie rejestry sprzed tego wywo³ania s¹ zachowywane.
; JMP MTSTOP   - Zakoñczenie pracy wielow¹tkowej i zwrócenie sterowania do
;                miejsca wywo³ania MTSTART.
;                Odbywa siê to równie¿ samoczynnie w razie zakoñczenia siê
;                wszystkich w¹tków.

ORG $100

;=======================================
; Program g³ówny

	; Uruchom zarz¹dcê wielow¹tkowoœci i pierwszy w¹tek.
	MOV	AX, THR1
	CALL	MTSTART
	; Praca wielow¹tkowa zosta³a zakoñczona.
	
	; Wróæ do DOS-u.
	MOV	AX, $4C00
	INT	$21


;=======================================
; Zarz¹dca wielow¹tkowioœci

ACCTHREADS	EQU 10 ; Dopuszczalna iloœæ w¹tków.

;---------------------------------------

MTSTART:
	; Rozpoczêcie pracy wielow¹tkowej i uruchomienie "w¹tku pierwotnego"
	; AX - adres pierwszego w¹tku.
	
	; Zachowaj adres powrotu.
	POP	WORD [MTRETURN]
	
	; Wpisz w¹tek pierwotny jako jedyny element tablicy w¹tków,
	; uczyñ go w¹tkiem bie¿¹cym i przejdŸ do niego.
	
	MOV	WORD [NXTHREAD], THTABLE+2
	MOV	WORD [THTABLE], AX
	MOV	WORD [CTHREAD], THTABLE
	
	JMP	AX

;---------------------------------------

MTSTOP:
	; Koniec pracy wielow¹tkowej.
	JMP	WORD [MTRETURN]

;---------------------------------------

MTPAUSE:
	; Wstrzymanie dzia³ania z perspektywy w¹tku bie¿¹cego, tj. zmiana 
	; w¹tku na kolejny w tablicy w¹tków.

	; Jeœli jest tylko jeden w¹tek, nic nie rób.
	CMP	WORD [NXTHREAD], THTABLE+2
	JA	MTMANY
	RET

MTMANY:
	; Istniej¹ conajmniej dwa w¹tki.

	; Zapisz, gdzie bie¿¹cy w¹tek przerwa³ pracê wywo³uj¹c MTPAUSE.
	POP	AX
	MOV	DI, WORD [CTHREAD]
	MOV	WORD [DI], AX
	
	; Wybierz w¹tek do przekazania sterowania.
	; Bêdzie nim nastêpny w¹tek w tablicy w¹tków, lub, je¿eli mamy do
	; czynienia z ostatnim w¹tkiem w tablicy - w¹tek na miejscu pierwszym.
	
	; Przesuñ DI jeden wpis na prawo.
	ADD	DI, 2
	; SprawdŸ, czy jesteœmy ju¿ poza u¿ywan¹ czêœci¹ tablicy.
	CMP	DI, WORD [NXTHREAD]
	JB	MTSELECTED
	
	; To by³ ostatni w¹tek - "zawróæ" do pierwszego.
	MOV	DI, THTABLE

MTSELECTED:
	; DI wskazuje na nowy bie¿¹cy w¹tek.
	; Zapisz, ¿e jest on w¹tkiem bie¿¹cym i przejdŸ do niego.
	
	MOV	WORD [CTHREAD], DI
	
	; Nale¿y pamiêtaæ, ¿e DI nie wskazuje bezpoœrednio adresu do
	; kontynuacji w¹tku, a wpis w tablicy w¹tków, który to stanowi w³aœnie
	; ten adres.
	MOV	AX, WORD [DI]
	; Teraz - w AX - mamy w³aœciwy adres pobrany z tablicy.
	JMP	AX

;---------------------------------------

MTFORK:
	PUSH	DI

	; Dopisz nowy w¹tek (z AX) do tablicy w¹tków.
	MOV	DI, WORD [NXTHREAD]
	MOV	WORD [DI], AX
	ADD	DI, 2
	MOV	WORD [NXTHREAD], DI
	
	POP	DI
	RET

;---------------------------------------

MTKILL:
	; Zakoñczenie bie¿¹cego w¹tku.

	; Usuñ bie¿¹cy w¹tek z tablicy w¹tków przesuwaj¹c o jedno miejsce w
	; lewo wpisy le¿¹ce za usuwanym wpisem.
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
	
	; SprawdŸ, czy pozosta³y jakiekolwiek w¹tki - je¿eli nie, zakoñcz
	; pracê wielow¹tkow¹.
	CMP	WORD [NXTHREAD], THTABLE
	JE	MTSTOP
	
	; Teraz, gdy bie¿¹cy w¹tek zostaæ usuniêty, trzeba przejœæ do jakiegoœ
	; innego w¹tku.
	; PrzejdŸ do w¹tku pierwszego w tablicy (bo tak).
	MOV	AX, WORD [THTABLE]
	MOV	WORD [CTHREAD], THTABLE
	JMP	AX

;---------------------------------------
; Dane zarz¹dcy wielow¹tkowoœci

MTRETURN:
	DW 0
	; Adres powrotu dla ca³ego zarz¹dcy.

THTABLE:
	TIMES ACCTHREADS DW 0
	; "Tablica w¹tków"
	; Dla ka¿dego w¹tku zawiera ona adres, od którego nale¿y wznowiæ
	; wykonywanie danego w¹tku.

CTHREAD:
	DW 0
	; WskaŸnik na bie¿¹cy w¹tek w tablicy w¹tków.

NXTHREAD:
	DW 0
	; WskaŸnik na miejsce dla nowego w¹tku w tablicy w¹tków.


;=======================================
; W¹tki

; Testem dla zarz¹dcy wielow¹tkowoœci bêdzie uruchomienie trzech w¹tków
; wyœwietlaj¹cych ci¹g odpowiednio liter A, B i C pracuj¹c na zmianê.
; W¹tek nr 1 jest odpowiedzialny za uruchomienie trzech pozosta³ych
; "w³aœciwych" w¹tków.
; Kod poni¿ej, tak samo jak program g³ówny, nie jest czêœci¹ samego zarz¹dcy
; wielow¹tkowoœci, a jedynie przyk³adowym jego u¿yciem.

THR1:
	; W¹tek 1.
	; Uruchamia w¹tki 2, 3 i 4 po czym zakañcza siê.
	
	MOV	AX, THR2
	CALL	MTFORK
	MOV	AX, THR3
	CALL	MTFORK
	MOV	AX, THR4
	CALL	MTFORK
	
	JMP	MTKILL

;---------------------------------------

THR2:
	; W¹tek 2. Wyœwietla 10 razy literê A.
	
	MOV	CL, 10
T2LOOP:
	MOV	BYTE [T2COUNT], CL

	; Wyœwietl znak za poœrednictwem DOS-u.
	MOV	AH, 2
	MOV	DL, 'A'
	INT	$21
	
	; Pozwól na zadzia³anie innych w¹tków.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T2COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T2LOOP
	
	JMP	MTKILL

T2COUNT:
	; Licznik powtórzeñ przechowywany w pamiêci.
	; Wa¿ne, aby by³ osobny dla ka¿dego z w¹tków.
	DB 0

;---------------------------------------

THR3:
	; W¹tek 3. Wyœwietla 15 razy literê B.
	
	MOV	CL, 15
T3LOOP:
	MOV	BYTE [T3COUNT], CL

	MOV	AH, 2
	MOV	DL, 'B'
	INT	$21
	
	; Pozwól na dzia³anie innych w¹tków.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T3COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T3LOOP
	
	JMP	MTKILL

T3COUNT:
	; Licznik powtórzeñ przechowywany w pamiêci.
	; Wa¿ne, aby by³ osobny dla ka¿dego z w¹tków.
	DB 0

;---------------------------------------

THR4:
	; W¹tek 4. Wyœwietla 20 razy literê C.
	
	MOV	CL, 20
T4LOOP:
	MOV	BYTE [T4COUNT], CL

	MOV	AH, 2
	MOV	DL, 'C'
	INT	$21
	
	; Pozwól na dzia³anie innych w¹tków.
	CALL	MTPAUSE
	
	MOV	CL, BYTE [T4COUNT]
	DEC	CL
	TEST	CL, CL
	JNZ	T4LOOP
	
	JMP	MTKILL

T4COUNT:
	; Licznik powtórzeñ przechowywany w pamiêci.
	; Wa¿ne, aby by³ osobny dla ka¿dego z w¹tków.
	DB 0