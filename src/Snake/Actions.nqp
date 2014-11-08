use NQPHLL;

# TODO: Proper variable handling. I think it might be relatively
# straightforward, actually. On reference, we'll have to check if the name has
# already been declared; if it isn't, mark it as free in the scope (free
# variables refer to variables in outer scopes). Then declarations can throw
# an error (or warn, in the case of nonlocal and global) if a name is declared
# after it's already been used.

class Snake::Actions is HLL::Actions;

method identifier($/) {
    make QAST::Var.new(:name(~$/), :scope<lexical>);
}

## 2.4: Literals
method string($/) { make $<quote_EXPR>.ast; }

## 2.5: Operators
#method prefix:sym<~>($/) { ... }
#method prefix:sym<+>($/) { ... }
#method prefix:sym<->($/) { ... }
#
#method infix:sym<+> ($/) { ... }
#method infix:sym<-> ($/) { ... }
#method infix:sym<*> ($/) { ... }
#method infix:sym<**>($/) { ... }
#method infix:sym</> ($/) { ... }
#method infix:sym<//>($/) { ... }
#method infix:sym<%> ($/) { ... }
#method infix:sym«<<»($/) { ... }
#method infix:sym«>>»($/) { ... }
#method infix:sym<&> ($/) { ... }
#method infix:sym<|> ($/) { ... }
#method infix:sym<^> ($/) { ... }
#method infix:sym«<» ($/) { ... }
#method infix:sym«>» ($/) { ... }
#method infix:sym«<=»($/) { ... }
#method infix:sym«>=»($/) { ... }
#method infix:sym<==>($/) { ... }
#method infix:sym<!=>($/) { ... }

method sports($/) {
    if $<EOF> { make 0 }
    else {
        my $indent := 0;
        $indent := $indent + nqp::chars(~$/[0]);
        if ~$/[1] {
            $indent := $indent + (8 - $indent % 8); # Increment to nearest multiple of 8
            $indent := $indent + 8*(nqp::chars(~$/[1])-1);
        }

        make $indent;
    }
}

# 6: Expressions
#method term:sym<identifier>($/) { make QAST::Var.new(:name(~$<identifier>), :scope<lexical>); }
method term:sym<identifier>($/) {
    my $ast := $<identifier>.ast;
    my %symbol := $*BLOCK.symbol: $ast.name;
    # If a variable is referenced that is not already declared in the scope,
    # that variable is free and refers to something in an outer scope. It is
    # an error to later declare it (that is, assign to it) or warnable to mark
    # it global/nonlocal.
    if !%symbol<declared> {
        $*BLOCK.symbol($ast.name, :free(1));
    }
    make $ast;
}
method term:sym<string>($/)     { make $<string>.ast; }
method term:sym<integer>($/)    { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)      { make QAST::NVal.new(:value($<dec_number>.ast)) }

method circumfix:sym<[ ]>($/) {
    my $ast := QAST::Op.new(:op<list>);
    for $<expression_list>.ast -> $e {
        $ast.push: $e;
    }
    make $ast;
}

method term:sym<nqp::op>($/) {
    my $op := QAST::Op.new(:op(~$<op>));
    for $<EXPR> -> $e {
        $op.push: $e.ast;
    }

    make $op;
}

method expression_list($/) {
    my $ast := [];
    for $<EXPR> -> $e {
        nqp::push($ast, $e.ast);
    }
    make $ast;
}

# 7: Simple statements
#method simple-statement:sym<expr>($/) { make $<EXPR>.ast; }
method simple-statement($/) {
    make $<assignment> ?? $<assignment>.ast !! $<EXPR>.ast;
}

method assignment($/) {
    my $var := $<identifier>.ast;
    self.add-declaration: $var.name;
    make QAST::Op.new(:op<bind>,
        $var,
        $<EXPR>.ast);
}

# 8: Compound statements
method compound-statement:sym<if>($/) {
    my $ast := QAST::Op.new(:op<if>, $<EXPR>.ast, $<suite>.ast);
    my $cur := $ast;
    while nqp::elems($<elif>) > 0 {
        my $new := QAST::Op.new(:op<if>, nqp::shift($<elif>).ast, nqp::shift($<elif>).ast);
        $cur.push: $new;
        $cur := $new;
    }
    $cur.push($<else>.ast) if $<else>;

    make $ast;
}

method compound-statement:sym<for>($/) {
    my $var := $<identifier>.ast;
    self.add-declaration: $var.name;
    $<suite>.ast.unshift: QAST::Op.new(:op<bind>,
        $var,
        QAST::Var.new(:name<$_>, :scope<lexical>));
    make QAST::Op.new(:op<for>, $<EXPR>.ast,
        QAST::Block.new(
            QAST::Stmts.new(QAST::Var.new(:name<$_>, :scope<lexical>, :decl<param>)),
            $<suite>.ast
        ))
}

method suite:sym<runon>($/) { make $<stmt-list>.ast; }

method suite:sym<normal>($/) {
    my $stmts := QAST::Stmts.new();
    for $<statement> -> $stmt {
        $stmts.push: $stmt.ast;
    }

    make $stmts;
}

method statement($/) { make $<stmt>.ast; }

method stmt-list($/) {
    my $stmts := QAST::Stmts.new();
    for $<simple-statement> -> $stmt {
        $stmts.push($stmt.ast);
    }

    make $stmts;
}

# 9: Top-level components
method file-input($/) {
    my $stmts := QAST::Stmts.new();
    for $<line> -> $line {
        $stmts.push($line.ast) if $line.ast;
    }
    $*BLOCK.push: $stmts;

    # XXX: This has been cargo-culted from Rakudo. Should probably figure out
    # how this API should be used (and what it can do).
    make QAST::CompUnit.new($*BLOCK, :hll<snake>);
}

method line($/) { make $<statement>.ast if $<statement>; }

# Appendix: Utility methods
method add-declaration($var) {
    my %sym := $*BLOCK.symbol: $var;
    if !%sym<declared> {
        nqp::die("Symbol $var referenced before being declared") if %sym<free>;
        $*BLOCK.symbol: $var, :declared(1);
        $*BLOCK[0].push: QAST::Var.new(:name($var), :scope<lexical>, :decl<var>);
    }
}

# vim: ft=perl6
