use NQPHLL;

class Snake::Actions is HLL::Actions;

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
method term:sym<string>($/)  { make $<string>.ast; }
method term:sym<integer>($/) { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)   { make QAST::NVal.new(:value($<dec_number>.ast)) }

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
method simple-statement:sym<expr>($/) { make $<EXPR>.ast; }

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

    # XXX: This has been cargo-culted from Rakudo. Should probably figure out
    # how this API should be used (and what it can do).
    make QAST::CompUnit.new(QAST::Block.new(QAST::Var.new(:name<__args__>,
        :scope<local>, :decl<param>, :slurpy(1)), $stmts), :hll<snake>);
}

method line($/) { make $<statement>.ast if $<statement>; }

# vim: ft=perl6
