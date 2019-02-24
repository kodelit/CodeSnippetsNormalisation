# CodeSnippetsNormalisation
![license](https://img.shields.io/badge/licencja-MIT-green.svg)
<a title="Tap for English version" href="README-en.md" alt="British flag">
        <img align="right" src="https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Flag_of_the_United_Kingdom.svg/28px-Flag_of_the_United_Kingdom.svg.png" /></a>

Projekt zawiera kod narzędzia wiersza poleceń **CodeSnippetsNormalisation**.
Narzędzie to jest częścią innego repozytorium ([CodeSnippets](https://github.com/kodelit/CodeSnippets)), w którym można znaleźć jego skompilowaną wersję

Jednak **udostępniam** również jego kod, **żeby**:

- pokazać jak proste jest pisanie nieskomplikowanych narzędzi (komend) wiersza poleceń przy użyciu języka *Swift*, o wiele prostsze niż przy użyciu skryptów *Bash'a*
- zainspirować cię do zmodyfikowania i użycia podobnego narzędzia do zarządzania twoimi snippetami.

### Co robi to narzędzie:

- Generuje znormalizowane skróty snippetów zgodnie ze zdefiniowanymi w nim zasadami (specyficznymi dla mojego sposobu nazewnictwa)
- Zmienia nazwy plików snippetów, które domyślnie są nieczytelne, bo zawierają tylko id danego snippeta, na tekst skrótu danego snippeta,
- Generuje/uaktualnia plik z listą wszystkich snippetów pod nazwą `ListOfSnippets.md`

Żeby zbudować niniejszy program należy uruchomić target `CodeSnippetsNormalisation` z urządzeniem ustawionym na `My Mac`

Target `CodeSnippetsNormalisation` w ustawieniach w zakładce *Build Phrases* zawiera skrypt **Copy built file to snippets dir**, który kopiuje zbudowany plik programu do katalogu zawierającego snippety Xcode'a, czyli do katalogu: `~/Library/Developer/Xcode/UserData/CodeSnippets`


