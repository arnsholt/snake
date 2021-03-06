use NQPHLL;

grammar Snake::Grammar is HLL::Grammar;

use Snake::Actions;
use Snake::ModuleLoader;
use Snake::World;

# Operator precedence levels, from tightest to loosest.
# Precedence levels not found in the standard grammar, since we factor
# things a bit differently, with invocation, calls and the like (what the
# standard grammar calls "primaries") being operators rather than separate
# lexical categories.
my %dotty     := nqp::hash('prec', 'z', 'assoc', 'unary');
my %subscript := nqp::hash('prec', 'y', 'assoc', 'unary');
my %call      := nqp::hash('prec', 'x', 'assoc', 'unary');

my %exponentiation := nqp::hash('prec', 'o', 'assoc', 'right');
my %unary          := nqp::hash('prec', 'n', 'assoc', 'unary');
my %multiplicative := nqp::hash('prec', 'm', 'assoc', 'left');
my %additive       := nqp::hash('prec', 'l', 'assoc', 'left');
my %bitshift       := nqp::hash('prec', 'k', 'assoc', 'left');
my %bitand         := nqp::hash('prec', 'j', 'assoc', 'left');
my %bitxor         := nqp::hash('prec', 'i', 'assoc', 'left');
my %bitor          := nqp::hash('prec', 'h', 'assoc', 'left');
my %relational     := nqp::hash('prec', 'g', 'assoc', 'left'); # TODO: Actually chaining operators
my %boolnot        := nqp::hash('prec', 'f', 'assoc', 'unary');
my %booland        := nqp::hash('prec', 'e', 'assoc', 'left');
my %boolor         := nqp::hash('prec', 'd', 'assoc', 'left');

method TOP() {
    my @*INDENT := nqp::list_i(0);
    my @*UNREPLACED-INDENT := nqp::list_i(0);
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
token NEWLINE { [<.ws> \n]+ }

### 2.1.9: Whitespace between tokens
token wsc    { <[\ \t\f]> }
token wsc-nl { <[\ \t\f\n]> }
token ws-nonl  { [<!ww> <.wsc>*    || <.wsc>+]    ['#' \N* | \\\n <.ws>]? }
token ws-nl    { [<!ww> <.wsc-nl>* || <.wsc-nl>+] ['#' \N* | \\\n <.ws>]? }
method ws() { $*WS_NL ?? self.ws-nl !! self.ws-nonl }

## 2.3: Identifiers and keywords
# TODO: xid_start/xid_continue, which is defined as anything that is
# equivalent to id_start/id_continue when NFKC-normalized.

my %keywords;

token identifier  { <id_start> <id_continue>* <?{!nqp::existskey(%keywords, ~$/)}>}

token id_start    { <+:Lu+:Ll+:Lt+:Lm+:Lo+:Nl+[_]+:Other_ID_Start> }
token id_continue { <+id_start+:Mn+:Mc+:Nd+:Pc+:Other_ID_Continue> }

### 2.3.1: Keywords

# XXX - None is also a keyword
for <
        False  class    finally is       return
               continue for     lambda   try
        True   def      from    nonlocal while
        and    del      global  not      with
        as     elif     if      or       yield
        assert else     import  pass
        break  except   in      raise
    > -> $keyword {
    %keywords{$keyword} := 1;
}

### 2.4.3: String literals
token string {
    # TODO: u, r, b, triple-quotes, pretty much all of 2.4.1.
    # TODO: String literal concatentation (2.4.2).
    <?['"]> <quote_EXPR: ':q'>
}

### 2.4.4: Integer literals

token decint  { [0|<[ 1..9 ]>\d*] }

token hexint  { [\d|<[ a..f A..F ]>]+ }

token octint  { <[0..7]>+ }

token binint  { <[01]>+ }

token integer {
    [
    | 0 [ [b|B] <VALUE=binint>
        | [o|O] <VALUE=octint>
        | [x|X] <VALUE=hexint>
        ]
    | <VALUE=decint>
    ]
}

### 2.4.5: Floating point literals

token dec_number {
    | $<coeff>=[     '.' \d+ ] <escale>?
    | $<coeff>=[ \d+ '.' \d* ] <escale>?
    | $<coeff>=[ \d+         ] <escale>
}

### 2.4.6: Imaginary literals
# TODO

## 2.5: Operators
# TODO: I think the default NQP arithmetic ops have slightly wrong semantics
# for Python.
token prefix:sym<~> { <sym> <O(|%unary, :op<bitneg_i>)> }
token prefix:sym<+> { <sym> <O(|%unary)> }
token prefix:sym<-> { <sym> <O(|%unary, :op<neg_n>)> }

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

token infix:sym<is> { <sym> <O(|%relational, :op<eqaddr>)> }

token infix:sym<and> { <sym> <O(|%booland, :op<if>)> }
token infix:sym<or> { <sym> <O(|%booland, :op<unless>)> }
token prefix:sym<not> { <sym> <O(|%boolnot, :op<isfalse>)> }

## 2.6: Delimiters
# Handled elsewhere, since we don't have a separate lexer stage.

token INDENT(int $want-replaced = -1, int $want-unreplaced = -1) {
    # Gobble up leading whitespace, push new indent onto stack (or die if bad
    # indent).
    <spaces-or-tabs> <?{ self.check-indent($<spaces-or-tabs>.ast, nqp::chars(~$<spaces-or-tabs>), $want-replaced, $want-unreplaced) }>
}

method ambigous-indent() {
    self.panic("Inconsistent use of tabs and spaces in indentation");
}

method check-indent(int $got-replaced, int $got-unreplaced, int $want-replaced, int $want-unreplaced) {
    if $want-replaced < 0 {
        if $got-replaced > nqp::atpos_i(@*INDENT, 0) {
            unless $got-unreplaced > nqp::atpos_i(@*UNREPLACED-INDENT, 0) {
                self.ambigous-indent;
            }

            nqp::unshift_i(@*INDENT, $got-replaced);
            nqp::unshift_i(@*UNREPLACED-INDENT, $got-unreplaced);

            1;
        }
        else {
            0;
        }
    }
    else {
        if $want-replaced == $got-replaced {
            unless $want-unreplaced == $got-unreplaced {
                self.ambigous-indent;
            }
            1;
        } else {
            0;
        }
    }
}

#token DEDENT {
#    <?before [^^ <spaces-or-tabs> [<?{ self.check-dedent($<spaces-or-tabs>.ast) }> || <.panic: "Dedent not consistent with any previous indent level">] | $<EOF>=<?> $]
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
    <spaces-or-tabs> [<?{ self.check-dedent($<spaces-or-tabs>.ast, nqp::chars(~$<spaces-or-tabs>)) }> || <.panic: "Dedent not consistent with any previous indent level">] | $<EOF>=<?> $
}

method check-dedent($replaced, $unreplaced) {
    # Pop indents until we find the level we've indented back to.
    while $replaced < nqp::atpos_i(@*INDENT, 0) { nqp::shift_i(@*INDENT) }

    while $unreplaced < nqp::atpos_i(@*UNREPLACED-INDENT, 0) { nqp::shift_i(@*UNREPLACED-INDENT) }

    $replaced == nqp::atpos_i(@*INDENT, 0)
}

# Spaces or tabs. 
token spaces-or-tabs {
    [ | ^^ \f? (' '|\t)*
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

# TODO: Dictionary comprehensions.
token circumfix:sym<( )> { '(' ~ ')' [:my $*WS_NL := 1; <.ws> <expression_list>?] }
token circumfix:sym<[ ]> {
    '[' ~ ']' [:my $*WS_NL := 1; <.ws>
        [ <list_comprehension>
        | <expression_list> ]?
    ]
}
token circumfix:sym<{ }> { '{' ~ '}' [:my $*WS_NL := 1; <.ws> <brace_list>?] }

rule list_comprehension {
    :my $*COMP_TARGET;
    <EXPR> <comp_for>
}
rule comp_for { for <identifier> in <EXPR('d')> <comp_iter>? }
token comp_iter { <subcomp=.comp_for> | <subcomp=.comp_if> }
# TODO: comp_if should actually have [<EXPR('d') | <lambda>], but lambdas
# aren't implemented yet.
rule comp_if { 'if' <EXPR('d')> <comp_iter>? }

token brace_list {
    | <dict=.dict_list>
    | <set=.expression_list>
}

rule dict_list {
    [<key=.EXPR> ':' <value=.EXPR>]+ % [ ',' ] ','?
}

token term:sym<nqp::op> {
    'nqp::' $<op>=[\w+] '(' ~ ')' [:s:my $*WS_NL := 1; <.ws>
        <positionals> [ ',' <nameds>]?
        | <nameds>
        | <?>
    ]
}

rule positionals { [<EXPR> <.ws> <?before \, | \)>]+ % [ \, ] }
rule nameds { [<identifier> \= <EXPR>]+ % [ \, ] }

## 6.3: Primaries
token postfix:sym<attribute> { '.' <identifier> <O(|%dotty)> }
token postcircumfix:sym<( )> {
    '(' ~ ')' [:s:my $*WS_NL := 1;
        <EXPR>+ % [ ',' ] [',' '*' <flat=.EXPR>]?
        | '*' <flat=.EXPR>
    ]? <O(|%call)>
}

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
    :my int $replaced := nqp::atpos_i(@*INDENT, 0);
    :my int $unreplaced := nqp::atpos_i(@*UNREPLACED-INDENT, 0);
    [:s<sym> <EXPR> ':' <suite>]
    [:s<.INDENT($replaced, $unreplaced)> 'elif' <elif=.EXPR> ':' <elif=.suite>]?
    [:s<.INDENT($replaced, $unreplaced)> 'else' ':' <else=.suite>]?
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

# TODO: Decorators
token compound-statement:sym<class> {
    [:s<sym> <identifier>
    {Snake::Actions.add-declaration: $<identifier>.ast.name}
    <inheritance>?
    ':'
    :my $*IN_DEF := 0;
    <new_scope(1)>]
}

token inheritance { <.ws> '(' ~ ')' [:s:my $*WS_NL := 1; <.ws> <expression_list>] }

token new_scope($in-class=0) {
    :my $*IN_CLASS := $in-class;
    :my $*BLOCK := QAST::Block.new(QAST::Stmts.new());
    <suite>
}

token parameter_list {
    '(' ~ ')' [:s:my $*WS_NL := 1;
        <parameter>+ % [ ',' ] [',' '*' <slurpy=.identifier>]?
        | '*' <slurpy=.identifier>
    ]?
}

# TODO: Parameter annotations
token parameter { [:s<identifier> ['=' <EXPR>]?] }

proto token suite {*}
token suite:sym<runon> { <stmt-list> <.NEWLINE> }
token suite:sym<normal> {
    <.NEWLINE>
    <.INDENT>
    # We need to save the current indent level *here*, between the INDENT
    # token and the first statement. If we do it after the statement, it'll be
    # broken.
    #
    # The breakage occurs if the suite contains a single compound statement.
    # In that case, we'll save the indent level of whatever comes after the
    # suite instead of the real one.
    :my int $replaced := nqp::atpos_i(@*INDENT, 0);
    :my int $unreplaced := nqp::atpos_i(@*UNREPLACED-INDENT, 0);
    <statement>
    [<.INDENT($replaced, $unreplaced)> <statement>]*
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
