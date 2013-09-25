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

method INDENT($/) {
    my $new := $<sports>.ast;
    my $old := @*INDENT[0];
    if $new > $old {
        nqp::unshift_i(@*INDENT, $new);
    }
    else {
        nqp::die("Bad indentation: new level $new seen, but old level is greater ($old)");
    }
}

method DEDENT($/) {
    my $new := $<sports>.ast;
    nqp::shift_i(@*INDENT) while $new < @*INDENT[0];
    nqp::die("Bad dedent: saw $new but expected @*INDENT[0]") if $new != @*INDENT[0];
}

method check-indent($/) {
    if $<sports> {
        my $got      := $<sports>.ast;
        my $expected := @*INDENT[0];
        nqp::die("Incorrect indentation: saw $got when expecting $expected") if $got != $expected;
    }
}

method sports($/) {
    my $indent := 0;
    $indent := $indent + nqp::chars(~$/[0]);
    if ~$/[1] {
        $indent := $indent + (8 - $indent % 8); # Increment to nearest multiple of 8
        $indent := $indent + 8*(nqp::chars(~$/[1])-1);
    }

    make $indent;
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
    say("if");
    make QAST::Op.new(:op<if>, $<EXPR>.ast, $<suite>.ast);
}

method suite($/) {
    make $<stmts>.ast;
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
