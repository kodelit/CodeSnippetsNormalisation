# CodeSnippetsNormalisation
![license](https://img.shields.io/badge/license-MIT-green.svg)
<a title="Kliknij by zmienić język na polski" href="README.md" alt="Polish flag">
        <img align="right" src="https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Flag_of_Poland.svg/22px-Flag_of_Poland.svg.png" /></a>
        
        
This project conteins code of command line tool named **CodeSnippetsNormalisation**.
The tool is a part of other repository ([CodeSnippets](https://github.com/kodelit/CodeSnippets)), where you can find it's built version.

The code here is public to:

- show how easy is to write a simple command line tool, and if your'e good at Swifting it's much easier to write such tool using *Swift* than using *bash script*
- inspire you to modify it and use to manage your own snippets.

### What does it do:

- generates normalised shortcuts according to some known predefined rules (secific to my own naming convention),
- sets up this shortcut as the snippet file name,
- generates/updates file `ListOfSnippets.md` listing all snippets

To build the tool run target `CodeSnippetsNormalisation` with device `My Mac` selected.

Target `CodeSnippetsNormalisation` in *Build Phrases* has **Copy built file to snippets dir**. It's a script which will copy built target to the xcode snippets directory `~/Library/Developer/Xcode/UserData/CodeSnippets`

