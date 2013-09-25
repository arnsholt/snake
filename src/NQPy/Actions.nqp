use NQPHLL;

class NQPy::Actions is HLL::Actions;

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

method check-indent($/) {
    if $<sports> {
        # TODO
    }
}

# 6: Expressions
method term:sym<string>($/)  { make $<string>.ast; }
method term:sym<integer>($/) { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)   { make QAST::NVal.new(:value($<dec_number>.ast)) }

method term:sym<nqp::op>($/) {
    my $op := QAST::Op.new(:op(~$<op>));
    for $<EXPR> -> $e {
        $op.push: $e.ast;
    }

    make $op;
}

# 7: Simple statements
method simple-statement:sym<expr>($/) { make $<EXPR>.ast; }

# 8: Compound statements
method compound-statement:sym<if>($/) {
    # TODO
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

    make QAST::Block.new($stmts);
}

method line($/) { make $<statement>.ast if $<statement>; }

# vim: ft=perl6
