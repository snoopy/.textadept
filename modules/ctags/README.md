# Ctags

Utilize Ctags with Textadept.

Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
*modules/* directory, and then putting the following in your *~/.textadept/init.lua*:

    require('ctags')

There will be a "Search > Ctags" menu.

There are four ways to tell Textadept about *tags* files:

  1. Place a *tags* file in a project's root directory. This file will be used in a tag
    search from any of that project's source files.
  2. Add a *tags* file or list of *tags* files to the [`ctags`](#ctags) module for a project root key.
     This file(s) will be used in a tag search from any of that project's source files. For
     example: `ctags['/path/to/project'] = '/path/to/tags'`.
  3. Add a *tags* file to the [`ctags`](#ctags) module. This file will be used in any tag search. For
     example: `ctags[#ctags + 1] = '/path/to/tags'`.
  4. As a last resort, if no *tags* files were found, or if there is no match for a given
     symbol, a temporary *tags* file is generated for the current file and used.

Textadept will use any and all *tags* files based on the above rules.

## Generating Ctags

This module can also help generate Ctags files that can be read by Textadept. This is
typically configured per-project. For example, a C project might want to generate tags for
all files and subdirectories in a *src/* directory:

    ctags.ctags_flags['/path/to/project'] = '-R src/'

A Lua project has a couple of options for generating tags:

    -- Use ctags with some custom flags for improved Lua parsing.
    ctags.ctags_flags['/path/to/project'] = ctags.LUA_FLAGS

Then, invoking Search > Ctags > Generate Project Tags menu item will generate the tags file.

## Key Bindings

Windows and Linux | macOS | Terminal | Command
-|-|-|-
**Search**| | |
F12 | F12 | F12 | Go to Ctag
Shift+F12 | ⇧F12 | S-F12 | Go to Ctag...

## Fields defined by `ctags`

<a id="ctags.LUA_FLAGS"></a>
### `ctags.LUA_FLAGS` 

A set of command-line options for ctags that better parses Lua code.
Combine this with other flags in [`ctags.ctags_flags`](#ctags.ctags_flags) if Lua files will be parsed.

<a id="ctags.ctags"></a>
### `ctags.ctags` 

Path to the ctags executable.
The default value is `'ctags'`.


## Functions defined by `ctags`

<a id="_G.textadept.editing.autocompleters.ctag"></a>
### `_G.textadept.editing.autocompleters.ctag`()

Autocompleter function for ctags. (Names only; not context-sensitive).
Does not remove duplicates.

<a id="ctags.goto_tag"></a>
### `ctags.goto_tag`(*tag*)

Jumps to the source of string *tag* or the source of the word under the caret.
Prompts the user when multiple sources are found.

Parameters:

- *tag*:  The tag to go to the source of.

Return:

- whether or not a tag was found and jumped to.


## Tables defined by `ctags`

<a id="ctags.ctags_flags"></a>
### `ctags.ctags_flags`

Map of project root paths to string command-line options, or functions that return such
strings, that are passed to ctags when generating project tags.

---
