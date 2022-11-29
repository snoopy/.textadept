Overview
---

Displays a filtered list of symbols (functions, variables, …)  
Does not require ctags to be installed, only the "tags" file must exist.

* `find_local`  
Will return only results in files matching the current filename.
I.e. searching in *file.c* will return matches from *file.h* and *file.c*.

* `find_global`  
Returns results from the entire current project.

* `function_list`  
Shows all functions/prototypes in the current file.

* `go_back`  
Returns to where the search started. Chaining is possible
but the top location is removed upon usage.

* `autocomplete`  
Autocompletes using all available symbols from the current project.

Usage
---

In your init.lua or keys.lua:

    tr_ctags = require('tr_ctags')
    keys.f1 = tr_ctags.find_local
    keys.f2 = tr_ctags.find_global
    keys.f3 = tr_ctags.function_list
    keys.f8 = tr_ctags.go_back
    keys.f9 = function() textadept.editing.autocomplete("ctags") end

Requirements
---

Create the "tags" file by calling ctags in the project top level directory

If other directories should be searched as well you can call ctags again with "-a path/to/other/dir" or symlink them.

It's recommended to use the following call to create the tags file
to ensure everything works as intended.  

    ctags -R --fields=+ain --extra=+fq --c++-kinds=+p --language-force=c++ --exclude="build" .

Acknowledgements
---
This module is based on Mitchell's ctags code posted on the
[Textadept wiki](http://foicica.com/wiki/ctags) and the default ctags module in Textredux.

