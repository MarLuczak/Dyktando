# Dyktando

Program czyta na głos słówka z listy, dziecko zapisuje je w zeszycie, a potem razem sprawdzacie, co poszło dobrze.
Działa na Windowsie, bez internetu i bez instalacji.

## Co potrafi

- Czyta słówka polskim głosem Windowsa (synteza mowy wbudowana w system)
- Ustawiasz: ile słówek w teście, ile razy czytać każde, przerwę po słówku, tempo i losową kolejność
- Start, pauza, stop i „Powtórz”, gdy dziecko nie dosłyszało
- Po teście lista słówek do porównania z zeszytem: zaznaczasz dobrze / źle
- Pamięta postępy: słówka oznaczone „Umiem” pomija, „Do powtórki” daje w każdym teście, a resztę dobiera tak, że najpierw idą te, których jeszcze nie było

## Jak uruchomić

1. Pobierz paczkę ZIP (zielony przycisk **Code → Download ZIP** albo zakładka **Releases**).
2. **Przed rozpakowaniem:** prawy przycisk na pliku ZIP → **Właściwości** → zaznacz **Odblokuj** → OK. Bez tego Windows może pytać o zgodę przy każdym uruchomieniu, bo plik pochodzi z internetu.
3. Rozpakuj i uruchom **`Dyktando.bat`**.

`Dyktando.bat` uruchamia skrypt `Dyktando.ps1` w PowerShellu z opcją `-ExecutionPolicy Bypass`. Ta opcja działa tylko na to jedno uruchomienie i nie zmienia ustawień komputera. Jest potrzebna, bo Windows domyślnie nie uruchamia skryptów PowerShell. Cały kod jest w `Dyktando.ps1`, możesz go przeczytać przed uruchomieniem.

## Słówka

Słówka są w pliku **`slowka.txt`**, po jednym w linii. W programie przycisk **„Edytuj słówka”** otwiera ten plik w Notatniku.
W paczce jest przykładowa lista 64 słówek z trudniejszą pisownią (ó/u, ż/rz, ch/h). Zamień ją na słówka z zeszytu albo z pracy domowej.

Postępy (oznaczenia „Umiem” / „Do powtórki” i liczniki) program zapisuje sam w pliku `slowka_stan.txt` obok. Usunięcie tego pliku zaczyna naukę od zera.

## Polski głos

Na polskim Windowsie 10 i 11 głos **Microsoft Paulina** jest zwykle wbudowany i nic nie trzeba robić.
Gdy go nie ma, program przy starcie pokaże ostrzeżenie, a słówka będą czytane głosem domyślnym (mogą brzmieć nie po polsku). Wtedy:
**Ustawienia → Czas i język → Mowa → Dodaj głosy → Polski**, potem uruchom program jeszcze raz.

## Wymagania

- Windows 10 lub 11
- Windows PowerShell 5.1 (jest w systemie)
- Głośniki albo słuchawki

## Autor i licencja

Autor: Marcin Łuczak. Program napisany w PowerShellu z pomocą AI.
Licencja: MIT, szczegóły w pliku [LICENSE](LICENSE).
