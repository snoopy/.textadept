* external
    * fonts

* lexers
    * custom c++ lexer which adds a rule for highlighting the last part of a namespace (e.g. in foo::bar::baz baz will be highlighted)

* modules
    * color - helper module for converting rgb to bgr
    * cpp - adds keyword autocompletion
    * ctags - modified ctags module based on the [official](https://github.com/orbitalquark/textadept-ctags) one
    * favorites - keep a list of favorite files independent of your session
    * format - custom module for source code formatters
    * git - provides various git functionality
        * blame (follows the cursor)
        * heatmap (marks lines depending on last committed date)
        * diff for specific line
        * show file at revision
    * [hydra](https://github.com/mhwombat/textadept-hydra) - enhanced keychains
    * origin - thin wrapper around textadept.history
    * perl - adds keyword autocompletion
    * quicknav - set and jump to locations in files quickly (saved per project)
    * run - run build and linter commands inline
    * [spellcheck](https://github.com/orbitalquark/textadept-spellcheck)
    * [My fork of Textredux](https://github.com/snoopy/textredux) - Provides a TUI for many TA dialogs
    * util - various utility functions

* init.lua - contains general preferences, (many) keybinds and snippets
