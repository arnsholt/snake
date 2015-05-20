use NQPHLL;

grammar Snake::Grammar is HLL::Grammar;

use Snake::Actions;
use Snake::ModuleLoader;
use Snake::World;

# Operator precedence levels, from tightest to loosest.
INIT {
    # Precedence levels not found in the standard grammar, since we factor
    # things a bit differently, with invocation, calls and the like (what the
    # standard grammar calls "primaries") being operators rather than separate
    # lexical categories.
    Snake::Grammar.O(':prec<z> :assoc<unary>', '%dotty');
    Snake::Grammar.O(':prec<y> :assoc<unary>', '%subscript');
    Snake::Grammar.O(':prec<x> :assoc<unary>', '%call');

    Snake::Grammar.O(':prec<o> :assoc<right>', '%exponentiation');
    Snake::Grammar.O(':prec<n> :assoc<unary>', '%unary');
    Snake::Grammar.O(':prec<m> :assoc<left>',  '%multiplicative');
    Snake::Grammar.O(':prec<l> :assoc<left>',  '%additive');
    Snake::Grammar.O(':prec<k> :assoc<left>',  '%bitshift');
    Snake::Grammar.O(':prec<j> :assoc<left>',  '%bitand');
    Snake::Grammar.O(':prec<i> :assoc<left>',  '%bitxor');
    Snake::Grammar.O(':prec<h> :assoc<left>',  '%bitor');
    Snake::Grammar.O(':prec<g> :assoc<left>',  '%relational'); # TODO: Actually chaining operators
    Snake::Grammar.O(':prec<f> :assoc<unary>', '%boolnot');
    Snake::Grammar.O(':prec<e> :assoc<left>',  '%booland');
    Snake::Grammar.O(':prec<d> :assoc<left>',  '%boolor');
}

method TOP() {
    my @*INDENT := nqp::list_i(0);
    # XXX: For the time being, we handle variables like NQP: Each scope is a
    # block, which has two Stmts children. We stick variable decls in the
    # first one, and put the actual code as the second one. Undeclared
    # variables are compile-time errors. This has to change at some point I
    # think, since variables can be created by other compilation units (again,
    # I think).
    my $*BLOCK := QAST::Block.new(QAST::Stmts.new(QAST::Var.new(:name<__args__>,
    :scope<local>, :decl<param>, :slurpy(1))));
    my $*UNIT := $*BLOCK;
    my $file := nqp::getlexdyn('$?FILES');
    my $source_id := nqp::sha1(self.target()) ~
        (%*COMPILING<%?OPTIONS><stable-sc> ?? '' !! '-' ~ ~nqp::time_n());
    my $*W := nqp::isnull($file) ??
        Snake::World.new(:handle($source_id)) !!
        Snake::World.new(:handle($source_id), :description($file));

    # Default variables are assigned to block-scoped lexicals numbered
    # sequentially. Naming derived from function definition and parameter name
    # won't work if a block contains two defs for the same function with the
    # same parameter names and different defaults (in an if, say).
    my $*DEFAULTS := 0;

    my $*IN_CLASS := 0;
    my $*IN_DEF := 0;
    my $*WS_NL := 0;

    return self.file-input;
}

# 2: Lexical analysis
## 2.1: Line structure
token NEWLINE { <.ws> [\n | $] }

### 2.1.9: Whitespace between tokens
token wsc    { <[\ \t\f]> }
token wsc-nl { <[\ \t\f\n]> }
# TODO: Line joining with backslash
token ws-nonl  { [<!ww> <.wsc>*    || <.wsc>+]    ['#' \N+ | \\\n <.ws>]? }
token ws-nl    { [<!ww> <.wsc-nl>* || <.wsc-nl>+] ['#' \N+ | \\\n <.ws>]? }
method ws() { $*WS_NL ?? self.ws-nl !! self.ws-nonl }

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
    <?['"]> <quote_EXPR: ':q'>
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
# TODO: I think the default NQP arithmetic ops have slightly wrong semantics
# for Python.
token prefix:sym<~> { <sym> <O('%unary, :op<bitneg_i>')> }
token prefix:sym<+> { <sym> <O('%unary')> }
token prefix:sym<-> { <sym> <O('%unary, :op<neg_n>')> }

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

token infix:sym<and> { <sym> <O('%booland, :op<if>')> }
token infix:sym<or> { <sym> <O('%booland, :op<unless>')> }
token prefix:sym<not> { <sym> <O('%boolnot, :op<isfalse>')> }

## 2.6: Delimiters
# Handled elsewhere, since we don't have a separate lexer stage.

token INDENT($indent = -1) {
    # Gobble up leading whitespace, push new indent onto stack (or die if bad
    # indent).
    <sports> <?{ self.check-indent($<sports>.ast, $indent) }>
}

method check-indent(int $sports, int $indent) {
    if $indent < 0 {
        if $sports > nqp::atpos_i(@*INDENT, 0) {
            nqp::unshift_i(@*INDENT, $sports);
            1 == 1;
        }
        else {
            1 == 0;
        }
    }
    else {
        $sports == $indent
    }
}

#token DEDENT {
#    <?before [^^ <sports> [<?{ self.check-dedent($<sports>.ast) }> || <.panic: "Dedent not consistent with any previous indent level">] | $<EOF>=<?> $]
#        || <.panic: "Dedent not at beginning of line">>
#}

# This is a really hacky implementation of DEDENT. Really we just want the
# version above. However, it looks like $/ isn't available inside a <?before>,
# so we do it this way and implement the zero-width match ourself. The reason
# this works is of course that match will always match successfully. If it
# fails (that is, we're trying to match a dedent somewhere other than
# beginning of line), it'll panic and throw an exception.
method DEDENT() {
    my $dedent := self.match-dedent;
    self;
}

token match-dedent {
    <sports> [<?{ self.check-dedent($<sports>.ast) }> || <.panic: "Dedent not consistent with any previous indent level">] | $<EOF>=<?> $
}

method check-dedent($sports) {
    # Pop indents until we find the level we've indented back to.
    while $sports < nqp::atpos_i(@*INDENT, 0) { nqp::shift_i(@*INDENT) }
    $sports == nqp::atpos_i(@*INDENT, 0);
}

# Spaces or tabs. A valid Python indent consists of any number of spaces, then
# any number of tabs. If spaces are used after a tab, the indent is ambiguous
# and must be rejected (2.1.8: "Indentation is rejected as inconsistent if a
# source file mixes tabs and spaces in a way that makes the meaning dependent
# on the worth of a tab in spaces").
token sports {
    [ | ^^ \f? (' '*) (\t*) [<[\ \f]> <.panic: "Ambiguous indentation">]?
      | $<EOF>=<?> $
    ]
    || <.panic: "Indent not at beginning of line">
}

# 6: Expressions
## 6.2: Atoms
token term:sym<identifier> { <identifier> }

token term:sym<string>  { <string> }
token term:sym<integer> { <integer> }
token term:sym<float>   { <dec_number> }

# TODO: An empty pair of parens constructs an empty tuple.
# TODO: List and dictionary comprehensions.
token circumfix:sym<( )> { '(' ~ ')' [:my $*WS_NL := 1; <.ws> <expression_list>?] }
token circumfix:sym<[ ]> { '[' ~ ']' [:my $*WS_NL := 1; <.ws> <expression_list>] }
token circumfix:sym<{ }> { '{' ~ '}' [:my $*WS_NL := 1; <.ws> <brace_list>?] }

token brace_list {
    | <dict=.dict_list>
    | <set=.expression_list>
}

rule dict_list {
    [<key=.EXPR> ':' <value=.EXPR>]+ % [ ',' ] ','?
}

token term:sym<nqp::op> { 'nqp::' $<op>=[\w+] '(' ~ ')' [:my $*WS_NL := 1; <EXPR>+ % [:s ',' ]] }

## 6.3: Primaries
token postfix:sym<attribute> { '.' <identifier> <O('%dotty')> }
token postcircumfix:sym<( )> { '(' ~ ')' [:my $*WS_NL := 1; <.ws> <expression_list>?] <O('%call')> }

## 6.13: Expression lists
rule expression_list { <EXPR>+ % [ ',' ][$<trailing>=[ ',' ]]? }

# 7: Simple statements
#proto token simple-statement {*}
#token simple-statement:sym<expr> { <EXPR> }
# XXX: Can't use protos here (or at least, I can't make it work) since
# expressions and assignments can't really be easily disambiguated via their
# declarative prefixes. Therefore, we first try to parse an assignment, and if
# that fails fall back to EXPR.
token simple-statement { <stmt=.assignment> || <stmt=.ordinary-statement> }

proto token ordinary-statement {*}
token ordinary-statement:sym<EXPR> { <EXPR> }
token ordinary-statement:sym<pass> { <sym> }
# TODO: Return actually takes a list of expressions, not a single one.
token ordinary-statement:sym<return> {
    <sym> <.ws> <EXPR>?
    [ <?{ $*IN_DEF == 1 }> {$*HAS_RETURN := 1} || <.panic: "Can only return when inside a function."> ]
}

# TODO: Handle all possible assignments.
rule assignment { <lhs=.EXPR('x')> '=' <rhs=.EXPR> }

token ordinary-statement:sym<break> { <sym> <.ws> }
token ordinary-statement:sym<continue> { <sym> <.ws> }

# 8: Compound statements
proto token compound-statement {*}
token compound-statement:sym<if> {
    :my int $indent := nqp::atpos_i(@*INDENT, 0);
    [:s<sym> <EXPR> ':' <suite>]
    [:s<.INDENT: $indent> 'elif' <elif=.EXPR> ':' <elif=.suite>]?
    [:s<.INDENT: $indent> 'else' ':' <else=.suite>]?
}

# TODO: Else part of while loop.
token compound-statement:sym<while> {
    [:s<sym> <EXPR> ':' <suite>]
}

# TODO: Full destructuring assignment.
# TODO: Else part of for loop.
token compound-statement:sym<for> {
    [:s<sym> <identifier>
    {Snake::Actions.add-declaration: $<identifier>.ast.name}
    in <EXPR> ':' <suite>]
}

# TODO: Decorators
# TODO: Return annotation
# TODO: Docstrings. The best way to extract and install this is probably a
# helper method that looks at the QAST::Block created by new_scope and removes
# an initial QAST::SVal and uses that to set the __doc__ member of the
# function object.
token compound-statement:sym<def> {
    [:s<sym> <identifier>
    {Snake::Actions.add-declaration: $<identifier>.ast.name}
    <parameter_list> ':'
    :my $*IN_DEF := 1;
    :my $*HAS_RETURN := 0;
    <new_scope>]
}

# TODO: Inheritance
# TODO: Decorators
token compound-statement:sym<class> {
    [:s<sym> <identifier>
    {Snake::Actions.add-declaration: $<identifier>.ast.name}
    <inheritance>?
    ':'
    :my $*IN_CLASS := 1;
    :my $*IN_DEF := 0;
    <new_scope>]
}

token inheritance { <.ws> '(' ~ ')' [:s:my $*WS_NL := 1; <.ws> <expression_list>] }

token new_scope {
    :my $*BLOCK := QAST::Block.new(QAST::Stmts.new());
    <suite>
}

token parameter_list { '(' ~ ')' [:s:my $*WS_NL := 1; <.ws> <parameter>* % [ ',' ]$<trailing>=[ ',' ]?] }

# TODO: Parameter annotations
token parameter { [:s<identifier> ['=' <EXPR>]?] }

proto token suite {*}
token suite:sym<runon> { <stmt-list> <.NEWLINE> }
token suite:sym<normal> {
    <.NEWLINE>
    <.INDENT> <statement>
    [<.INDENT: nqp::atpos_i(@*INDENT, 0)> <statement>]*
    <.DEDENT>
}

token statement {
    | <stmt=.stmt-list> <.NEWLINE>
    | <stmt=.compound-statement>
    | 'YOU_ARE_HERE' <.NEWLINE> <stmt=.you_are_here>
}

# Just a placeholder so the action gets called.
token you_are_here { <?> }

token stmt-list { <simple-statement>+ %% [<.ws> ';' <.ws>] }

# 9: Top-level components
token file-input { <line>* [$ || <.panic: 'Trailing text'>] }
token line { ^^ <.NEWLINE> | <statement> }

# vim: ft=perl6
