use NQPHLL;

use Snake::Metamodel::ClassHOW;

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
    #my %symbol := $*BLOCK.symbol: $ast.name;
    ## If a variable is referenced that is not already declared in the scope,
    ## that variable is free and refers to something in an outer scope. It is
    ## an error to later declare it (that is, assign to it) or warnable to mark
    ## it global/nonlocal.
    #if !%symbol<declared> {
    #    $*BLOCK.symbol($ast.name, :free(1));
    #}
    make $ast;
}
method term:sym<string>($/)     { make $<string>.ast; }
method term:sym<integer>($/)    { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)      { make QAST::NVal.new(:value($<dec_number>.ast)) }

method circumfix:sym<( )>($/) {
    if +$<expression_list>.ast > 1 || $<expression_list><trailing> {
        nqp::die("Tuples NYI");
    }
    else {
        make $<expression_list>.ast[0]
    }
}

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

method make-attribute($/) {
    make QAST::Block.new(:blocktype<immediate>,
        QAST::Var.new(:name<$_>, :scope<local>, :decl<var>),
        QAST::Op.new(:op<bind>,
            QAST::Var.new(:name<$_>, :scope<local>),
            $/[0].ast
        ),
        QAST::Op.new(:op<if>,
            QAST::Op.new(:op<isconcrete>,
                QAST::Var.new(:name<$_>, :scope<local>),
            ),
            QAST::Stmts.new(
                # nqp::getattr($_, $_.WHAT, $<OPER><identifier>.name) //
                #     $_.HOW.find_attribute($_, $<OPER><identifier>.name)
                QAST::Op.new(:op<ifnull>,
                    QAST::Op.new(:op<getattr>,
                        QAST::Var.new(:name<$_>, :scope<local>),
                        QAST::Op.new(:op<what>, QAST::Var.new(:name<$_>, :scope<local>)),
                        QAST::SVal.new(:value($<OPER><identifier>.ast.name)),
                    ),
                    QAST::Op.new(:op<callmethod>, :name<find_attribute>,
                        QAST::Op.new(:op<how>, QAST::Var.new(:name<$_>, :scope<local>)),
                        QAST::Var.new(:name<$_>, :scope<local>),
                        QAST::SVal.new(:value($<OPER><identifier>.ast.name)),
                    ),
                ),
            ),
            QAST::Stmts.new(
                QAST::Op.new(:op<callmethod>, :name<find_attribute>,
                    QAST::Op.new(:op<how>, QAST::Var.new(:name<$_>, :scope<local>)),
                    QAST::Var.new(:name<$_>, :scope<local>),
                    QAST::SVal.new(:value($<OPER><identifier>.ast.name)),
                ),
            ),
        ),
    );
}

method postcircumfix:sym<( )>($/) {
    my $ast := QAST::Op.new(:op<call>);
    if $<expression_list> {
        for $<expression_list>.ast -> $e {
            $ast.push: $e;
        }
    }
    make $ast;
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
    make $<stmt>.ast;
}

method ordinary-statement:sym<EXPR>($/) { make $<EXPR>.ast; }
method ordinary-statement:sym<pass>($/) { make QAST::Stmts.new(); }

method ordinary-statement:sym<return>($/) {
    # TODO: Bare return should return None.
    make QAST::Op.new(:op<call>, :name<$RETURN>,
        $<EXPR> ?? $<EXPR>.ast !! QAST::Stmts.new());
}

method ordinary-statement:sym<break>($/) { make QAST::Op.new(:op<control>, :name<last>); }
method ordinary-statement:sym<continue>($/) { make QAST::Op.new(:op<control>, :name<next>); }

method assignment($/) {
    if $<lhs><identifier> {
        my $var := $<lhs><identifier>.ast;
        self.add-declaration: $var.name;
        make QAST::Op.new(:op<bind>,
            $var,
            $<rhs>.ast);
    }
    elsif $<lhs><postfix> {
        make QAST::Block.new(:blocktype<immediate>,
            QAST::Var.new(:name<$_>, :scope<local>, :decl<var>),
            QAST::Op.new(:op<bind>,
                QAST::Var.new(:name<$_>, :scope<local>),
                $<lhs>[0].ast
            ),
            QAST::Op.new(:op<callmethod>, :name<bind_attribute>,
                QAST::Op.new(:op<how>, QAST::Var.new(:name<$_>, :scope<local>)),
                QAST::Var.new(:name<$_>, :scope<local>),
                QAST::SVal.new(:value($<lhs><postfix><identifier>.ast.name)),
                $<rhs>.ast,
            ),
        );
    }
    elsif $<lhs><postcircumfix> {
        # TODO
    }
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

method compound-statement:sym<while>($/) {
    make QAST::Op.new(:op<while>, $<EXPR>.ast, $<suite>.ast);
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

# TODO: A function without an explicit return should return None in Python. We
# currently have the same semantics as Perl (and others), returning the value
# of the last statement in the block.
method compound-statement:sym<def>($/) {
    my $block := $<new_scope>.ast;
    my $name := $<identifier>.ast.name;
    $block.name: $name;

    if $*HAS_RETURN {
        $block[1] := QAST::Op.new(:op<lexotic>, :name<$RETURN>, $block[1]);
    }

    my $ast := QAST::Stmts.new(QAST::Op.new(:op<bind>,
            QAST::Var.new(:name($name), :scope<lexical>),
            $block));

    for $<parameter_list>.ast -> $p {
        $block[0].push: $p.ast;
        if $p<EXPR> {
            my $default-name := '$default' ~ $*DEFAULTS++;
            my $var := QAST::Var.new(:name($default-name), :scope<lexical>);
            $*BLOCK[0].push: QAST::Var.new(:name($default-name),
                :scope<lexical>, :decl<var>);
            $p.ast.default($var);
            $ast.push: QAST::Op.new(:op<bind>,
                $var,
                $p<EXPR>.ast);
        }
    }

    if $*IN_CLASS {
        $ast.push: QAST::Op.new(:op<callmethod>, :name<bind_attribute>,
            QAST::Op.new(:op<how>, QAST::Var.new(:name<$class>, :scope<local>)),
            QAST::Var.new(:name<$class>, :scope<local>),
            QAST::SVal.new(:value($name)),
            QAST::Var.new(:name($name), :scope<lexical>),
        );
    }

    make $ast;
}

method compound-statement:sym<class>($/) {
    my $name := $<identifier>.ast.name;
    my $block := $<new_scope>.ast;
    $block.blocktype: 'immediate';

    $block[0].push: QAST::Var.new(:name<$class>, :scope<local>, :decl<var>);
    $block[1].unshift: QAST::Op.new(:op<bind>,
        QAST::Var.new(:name<$class>, :scope<local>),
        QAST::Op.new(:op<callmethod>, :name<new_type>,
            QAST::WVal.new(:value(Snake::Metamodel::ClassHOW)),
            QAST::SVal.new(:value($name), :named<name>),
        ),
    );
    $block[1].push: QAST::Var.new(:name<$class>, :scope<local>);

    make QAST::Op.new(:op<bind>,
        QAST::Var.new(:name($name), :scope<lexical>),
        $block
    );
}

method new_scope($/) {
    $*BLOCK.push: $<suite>.ast;
    make $*BLOCK;
}

method parameter_list($/) {
    my $ast := [];
    for $<parameter> -> $p {
        nqp::push($ast, $p);
    }
    make $ast;
}

method parameter($/) {
    make QAST::Var.new(:name($<identifier>.ast.name),
        :scope<lexical>, :decl<param>);
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

method you_are_here($/) { make self.CTXSAVE() }

method stmt-list($/) {
    if +$<simple-statement> > 1 {
        my $stmts := QAST::Stmts.new();
        for $<simple-statement> -> $stmt {
            $stmts.push($stmt.ast);
        }
        make $stmts;
    }
    else { make $<simple-statement>[0].ast; }
}

# 9: Top-level components
method file-input($/) {
    my $stmts := QAST::Stmts.new();
    for $<line> -> $line {
        $stmts.push($line.ast) if $line.ast;
    }
    $*BLOCK.push: $stmts;

    unless nqp::defined(%*COMPILING<%?OPTIONS><outer_ctx>) {
        # We haven't got a specified outer context already, so load a
        # setting.
        my $SETTING := $*W.load_setting(%*COMPILING<%?OPTIONS><setting> // 'SNAKE');
    }
    self.SET_BLOCK_OUTER_CTX($*BLOCK);

    # XXX: This has been cargo-culted from Rakudo. Should probably figure out
    # how this API should be used (and what it can do).
    make QAST::CompUnit.new(
        :hll<snake>,

        :sc($*W.sc()),
        :pre_deserialize($*W.load_dependency_tasks()),
        :post_deserialize($*W.fixup_tasks()),

        # TODO: These need to be different when we do modules and such
        # properly.
        :load(QAST::Op.new(:op<call>, QAST::BVal.new(:value($*BLOCK)))),
        :main(QAST::Op.new(:op<call>, QAST::BVal.new(:value($*BLOCK)))),

        $*BLOCK,
    );
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

# We need custom handling for the attribute lookups. Syntactically, it makes
# sense to handle it as a postfix (like NQP and Rakudo), but the code we
# generate for it has to be different.
method EXPR($/, $key?) {
    if $key && $key eq "POSTFIX" && $<OPER><O><prec> eq 'z' {
        self.make-attribute($/);
    }
    else {
        HLL::Actions.EXPR($/, $key);
    }
}

# vim: ft=perl6
