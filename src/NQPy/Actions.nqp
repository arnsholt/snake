use NQPHLL;

class NQPy::Actions is HLL::Actions;

method program($/) {
    my $stmts := QAST::Stmts.new();
    for $<statement> {
        $stmts.push($_.ast);
    }

    make QAST::Block.new($stmts);
}

method statement:sym<print>($/) {
    make QAST::Op.new(:op<say>, $<EXPR>.ast);
}

## 2.4: Literals
method string($/) { make $<quote_EXPR>.ast; }

## 2.5: Operators
# TODO

# 6: Expressions
method term:sym<string>($/)  { make $<string>.ast; }
method term:sym<integer>($/) { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)   { make QAST::NVal.new(:value($<dec_number>.ast)) }

# 7: Simple statements
# TODO

# 8: Compound statements
# TODO

# vim: ft=perl6
