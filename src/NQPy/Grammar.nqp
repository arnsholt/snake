use NQPHLL;

grammar NQPy::Grammar is HLL::Grammar;

method TOP() {
    my @*INDENT := nqp::list_i(0);

    return self.file-input;
}

# 2: Lexical analysis
## 2.1: Line structure
token NEWLINE { <.ws> [\n | $] }

### 2.1.9: Whitespace between tokens
token wsc { <[\ \t\f]> }
# TODO: Line joining with backslash
token ws  { <!ww> <.wsc>* ['#' \N+]? || <.wsc>+ ['#' \N+]? }

## 2.3: Identifiers and keywords
# TODO: xid_start/xid_continue, which is defined as anything that is
# equivalent to id_start/id_continue when NFKC-normalized.
token identifier  { <id_start> <id_continue>* }
# Other_ID_Start and _Continue don't exist in NQP yet, so let's skip those for
# now.
#token id_start    { <+:Lu+:Ll+:Lt+:Lm+:Lo+:Nl+[_]+:Other_ID_Start> }
#token id_continue { <+id_start+:Mn+:Mc+:Nd+:Pc+:Other_ID_Continue> }
token id_start    { <+:Lu+:Ll+:Lt+:Lm+:Lo+:Nl+[_]> }
token id_continue { <+id_start+:Mn+:Mc+:Nd+:Pc> }

### 2.3.1: Keywords
proto token keyword {*}
token keyword:sym<False>    { <sym> }
token keyword:sym<class>    { <sym> }
token keyword:sym<finally>  { <sym> }
token keyword:sym<is>       { <sym> }
token keyword:sym<return>   { <sym> }
token keyword:sym<None>     { <sym> }
token keyword:sym<continue> { <sym> }
token keyword:sym<for>      { <sym> }
token keyword:sym<lambda>   { <sym> }
token keyword:sym<try>      { <sym> }
token keyword:sym<True>     { <sym> }
token keyword:sym<def>      { <sym> }
token keyword:sym<from>     { <sym> }
token keyword:sym<nonlocal> { <sym> }
token keyword:sym<while>    { <sym> }
token keyword:sym<and>      { <sym> }
token keyword:sym<del>      { <sym> }
token keyword:sym<global>   { <sym> }
token keyword:sym<not>      { <sym> }
token keyword:sym<with>     { <sym> }
token keyword:sym<as>       { <sym> }
token keyword:sym<elif>     { <sym> }
token keyword:sym<if>       { <sym> }
token keyword:sym<or>       { <sym> }
token keyword:sym<yield>    { <sym> }
token keyword:sym<assert>   { <sym> }
token keyword:sym<else>     { <sym> }
token keyword:sym<import>   { <sym> }
token keyword:sym<pass>     { <sym> }
token keyword:sym<break>    { <sym> }
token keyword:sym<except>   { <sym> }
token keyword:sym<in>       { <sym> }
token keyword:sym<raise>    { <sym> }

### 2.4.3: String literals
token string {
    # TODO: u, r, b, triple-quotes, pretty much all of 2.4.1.
    # TODO: String literal concatentation (2.4.2).
    <?["]> <quote_EXPR: ':q'>
}

### 2.4.4: Integer literals
# Currently handled with HLL::Grammar's built-in <integer>.
# XXX: Overgenerates a bit, since it accepts 0dXXX decimal ints.
# XXX: Undergenerates a bit, since it doesn't accept 0X, 0O and 0B.

### 2.4.5: Floating point literals
# Currently handled with HLL::Grammar's built-in <dec_number>. I think it even
# covers the same cases as Python wants.

### 2.4.6: Imaginary literals
# TODO

## 2.5: Operators
# TODO: Precedence levels
token prefix:sym<~> { <sym> }
token prefix:sym<+> { <sym> }
token prefix:sym<-> { <sym> }

token infix:sym<+>  { <sym> }
token infix:sym<->  { <sym> }
token infix:sym<*>  { <sym> }
token infix:sym<**> { <sym> }
token infix:sym</>  { <sym> }
token infix:sym<//> { <sym> }
token infix:sym<%>  { <sym> }
token infix:sym«<<» { <sym> }
token infix:sym«>>» { <sym> }
token infix:sym<&>  { <sym> }
token infix:sym<|>  { <sym> }
token infix:sym<^>  { <sym> }
token infix:sym«<»  { <sym> }
token infix:sym«>»  { <sym> }
token infix:sym«<=» { <sym> }
token infix:sym«>=» { <sym> }
token infix:sym<==> { <sym> }
token infix:sym<!=> { <sym> }

## 2.6: Delimiters
# Handled elsewhere, since we don't have a separate lexer stage.

token INDENT {
    # Gobble up leading whitespace, push new indent onto stack (or die if bad
    # indent).
    #<!> # TODO
    ^^ <sports> <.MARKER: 'INDENT'> || <.panic: "Dedent not at beginning of line!">
}

token DEDENT {
    # Gobble up leading whitespace, pop until we're done (or die if bad
    # indent).
    [^^ <sports> <.MARKER: 'INDENT'> | $<EOF>=<?> $] || <.panic: "Indent not at beginning of line!">
}

token check-indent {
    <.MARKED: 'INDENT'> || ^^ <sports>
}

# Spaces or tabs. A valid Python indent consists of any number of spaces, then
# any number of tabs. If spaces are used after a tab, the indent is ambiguous
# and must be rejected (2.1.8: "Indentation is rejected as inconsistent if a
# source file mixes tabs and spaces in a way that makes the meaning dependent
# on the worth of a tab in spaces").
token sports { \f? (' '*) (\t*) [<[\ \f]> <.panic: "Ambiguous indentation">]? }

# 6: Expressions
## 6.2: Atoms
token term:sym<identifier> { <identifier> }

token term:sym<string>  { <string> }
token term:sym<integer> { <integer> }
token term:sym<float>   { <dec_number> }

token circumfix:sym<( )> { '(' <.ws> <expression_list> ')' }

token term:sym<nqp::op> { 'nqp::' $<op>=[\w+] '(' ~ ')' [<EXPR>+ % [:s ',' ]] }

## 6.13: Expression lists
rule expression_list { <EXPR>+ % [ ',' ]$<trailing>=[ ',' ]? }

# 7: Simple statements
proto token simple-statement {*}
token simple-statement:sym<expr> { <EXPR> }

# 8: Compound statements
proto token compound-statement {*}
rule compound-statement:sym<if> { <sym> <EXPR> ':' <suite> }

proto token suite {*}
token suite:sym<runon> { <stmt-list> <.NEWLINE> }
token suite:sym<normal> { <.NEWLINE> <.INDENT> <statement>+ <.DEDENT> }

token statement { <.check-indent> [$<stmt>=<stmt-list> <.NEWLINE> | $<stmt>=<compound-statement>] }

token stmt-list { <simple-statement>+ %% [<.ws> ';' <.ws>] }

# 9: Top-level components
token file-input { <line>* [$ || <.panic: 'Trailing text'>] }
token line { ^^ <.NEWLINE> | <statement> }

# vim: ft=perl6
