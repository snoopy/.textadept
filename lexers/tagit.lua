-- tagit LPeg lexer.
--
-- Lexes the tagit status buffer. It is line-based: each line is classified independently.
-- Diff lines are tagged exactly like the built-in `diff` lexer so the theme's colors apply,
-- while tagit's own structural lines (section headers, branch header) get heading/keyword styling.
-- File-line status codes are colored directly via Scintilla styling in `status.lua`, not by this lexer.

local lexer = lexer
local to_eol, starts_line = lexer.to_eol, lexer.starts_line
local P, S = lpeg.P, lpeg.S

local lex = lexer.new(..., { lex_by_line = true })

-- Diff hunk location and changes (same tags as the diff lexer).
lex:add_rule('location', lex:tag(lexer.NUMBER, to_eol(starts_line(P('@@')))))
lex:add_rule('addition', lex:tag('addition', to_eol(starts_line(P('+')))))
lex:add_rule('deletion', lex:tag('deletion', to_eol(starts_line(P('-')))))

-- tagit structural lines.
local section_word = P('Files') + 'Untracked' + 'Unstaged' + 'Staged' + 'Unmerged' + 'Recent' + 'Stashes'
lex:add_rule('section', lex:tag(lexer.HEADING, to_eol(starts_line(section_word))))
lex:add_rule('head', lex:tag(lexer.KEYWORD, to_eol(starts_line(P('Head:') + 'Upstream:'))))

-- Dim footer hint.
lex:add_rule('hint', lex:tag(lexer.COMMENT, to_eol(starts_line(P('Press ?')))))

-- Style-slot-only tags for status-code and commit-field coloring in status.lua.
-- These patterns never match; they merely allocate Scintilla style slots for
-- tag names that the themes have colored (e.g. lexer.STRING = green, lexer.CONSTANT = orange).
lex:add_rule('_string', lex:tag(lexer.STRING, S('')))
lex:add_rule('_constant', lex:tag(lexer.CONSTANT, S('')))
lex:add_rule('_function', lex:tag(lexer.FUNCTION, S('')))
lex:add_rule('_type', lex:tag(lexer.TYPE, S('')))

-- No-op fold handler: prevents Scintillua's default folder (which classifies lines by their first character)
-- from overriding the fold levels that status.lua assigns from metadata.
-- Returns an empty table so no levels are changed during lexing; assign_fold_levels() in status.lua handles it.
lex.fold = function()
  return {}
end

return lex
