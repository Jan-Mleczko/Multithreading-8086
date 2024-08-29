## Zarządca wielowątkowości dla procesorów zgodnych z i8086(R), tzn. rodziny x86

Całość działa jako jeden program pod DOS-em. Kod wszystkich wątków wraz z samym zarządcą musi mieścić się w jednym segmencie, jako że stosowane są bliskie skoki i wywołania oraz 16-bitowe adresy bez segmentu. W celu umożliwienia przełączania między wątkami każdy wątek musi co jakiś czas wywoływać procedurę "daj czas innym wątkom".

Załączono program zawierający zarządcę wraz z testowym wykorzystaniem. Po asemblacji - składnia dla FASM - otrzymujemy wykonywalny program o objętości 266 bajtów, i to włącznie z procedurami testującymi!

Funkcjonalności:

* Zarządzanie czasem dla określonej liczby "równolegle" pracujących wątków. Nie chodzi o wykorzystanie wielu rdzeni.
* Uruchomienie nowego wątku z jednego z wątków.
* Zakończenie bieżącego wątku lub wszystkich wątków.

Więcej szczegółów w komentarzach w kodzie.

Projekt ten będzie rozwijany, jako że jest jeszcze wiele do dodania, np. możliwość pobrania uchwytu innego wątku w celu sprawdzenia jego stanu lub wymuszenia jego zakończenia.

## A multithreading engine working on the i8086 and compatible, i. e. the whole x86 CPU family

The whole program, the multithreading engine and the main code that uses it, are contained in a single DOS executable. The assembly language syntax is meant to be assembled with the Flat Assembler.
