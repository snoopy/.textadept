* init.lua - contains general preferences, (many) keybinds and snippets

* modules
    * clippy - stores and recalls clipboard history
    * color - helper module for converting RGB to BGR
    * cpp - C++ keyword auto-completion
    * ctags - modified ctags module based on the [official](https://github.com/orbitalquark/textadept-ctags) one
    * favorites - persistent favorite files list independent of session
    * git - provides various git functionality
        * blame (follows the cursor)
        * heatmap (marks lines depending on last committed date)
        * diff for specific line
        * show file at revision
    * [hydra](https://github.com/mhwombat/textadept-hydra) - enhanced keychains
    * perl - Perl keyword auto-completion
    * quicknav - set and jump to marked locations (saved per project)
    * run - run build/lint commands inline
    * [spellcheck](https://github.com/orbitalquark/textadept-spellcheck)
    * [My fork of Textredux](https://github.com/snoopy/textredux) - TUI dialogs for many Textadept features
    * util - utility functions

* lexers
    * custom c++ lexer which adds a rule for highlighting the last part of a namespace (e.g. in foo::bar::baz baz will be highlighted)

* external
    * fonts

