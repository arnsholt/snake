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
    make QAST::VarWithFallback.new(:name(~$/), :scope<lexical>,
        :fallback(QAST::Op.new(:op<die>,
            QAST::SVal.new(:value("Can't read unassigned variable $/")))));
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
method term:sym<identifier>($/) { make $<identifier>.ast; }
method term:sym<string>($/)     { make $<string>.ast; }
method term:sym<integer>($/)    { make QAST::IVal.new(:value($<integer>.ast)) }
method term:sym<float>($/)      { make QAST::NVal.new(:value($<dec_number>.ast)) }

method circumfix:sym<( )>($/) {
    if !$<expression_list> || +$<expression_list>.ast > 1 || $<expression_list><trailing> {
        # TODO: At some point, tuples should probably not be raw NQP lists.
        my $list := QAST::Op.new(:op<list>);
        my $i := 0;
        my $elems := $<expression_list> ?? +$<expression_list>.ast !! 0;
        while $i < $elems {
            $list.push: $<expression_list>.ast[$i];
            $i++;
        }
        make $list;
    }
    else {
        make $<expression_list>.ast[0]
    }
}

method circumfix:sym<[ ]>($/) {
    if $<list_comprehension> { make $<list_comprehension>.ast }
    else {
        my $ast := QAST::Op.new(:op<list>);
        my @exprs := $<expression_list> ?? $<expression_list>.ast !! [];
        for @exprs -> $e {
            $ast.push: $e;
        }
        make $ast;
    }
}

method circumfix:sym<{ }>($/) {
    if !$<brace_list> || $<brace_list><dict> {
        my $hash := QAST::Op.new(:op<hash>);
        my $i := 0;
        my $elems := $<brace_list> ?? +$<brace_list><dict><key> !! 0;
        while $i < $elems {
            $hash.push: $<brace_list><dict><key>[$i].ast;
            $hash.push: $<brace_list><dict><value>[$i].ast;
            $i++;
        }
        make $hash;
    }
    else {
        nqp::die("Sets NYI");
    }
}

method list_comprehension($/) {
    $*COMP_TARGET.push: QAST::Op.new(:op<push>,
        QAST::Var.new(:name<$>, :scope<lexical>),
        $<EXPR>.ast);
    make QAST::Stmts.new(:resultchild(0),
        QAST::Op.new(:op<bind>,
            QAST::Var.new(:name<$>, :scope<lexical>, :decl<var>),
            QAST::Op.new(:op<list>)),
        $<comp_for>.ast);
}

method comp_for($/) {
    my $ast := QAST::Block.new(
        QAST::Var.new(:name($<identifier>.ast.name), :scope<lexical>, :decl<param>));
    if $<comp_iter> { $ast.push: $<comp_iter>.ast }
    else { $*COMP_TARGET := $ast }
    make QAST::Op.new(:op<for>, $<EXPR>.ast, $ast);
}

method comp_iter($/) { make $<subcomp>.ast }

method comp_if($/) {
    my $ast := QAST::Stmts.new();
    if $<comp_iter> { $ast.push: $<comp_iter>.ast }
    else { $*COMP_TARGET := $ast }
    make QAST::Op.new(:op<if>,
        $<EXPR>.ast,
        $ast);
}

method term:sym<nqp::op>($/) {
    my $op := QAST::Op.new(:op(~$<op>));
    if $<positionals> {
        for $<positionals>.ast -> $p { $op.push: $p }
    }

    if $<nameds> {
        for $<nameds>.ast -> $n { $op.push: $n }
    }
    make $op;
}

method positionals($/) {
    my $ast := [];
    for $<EXPR> -> $e { $ast.push: $e.ast; }
    make $ast;
}

method nameds($/) {
    my $ast := [];
    my $i := 0;
    while $i < +$<identifier> {
        my $e := $<EXPR>[$i].ast;
        $e.named: $<identifier>[$i].ast.name;
        $ast.push: $e;
        $i++;
    }
    make $ast;
}

method make-attribute($/) {
    make self.special-call($/[0].ast, '__getattribute__',
        QAST::SVal.new(:value($<OPER><identifier>.ast.name)));
}

method postcircumfix:sym<( )>($/) {
    my $ast := QAST::Op.new(:op<call>);
    if $<EXPR> {
        for $<EXPR> -> $e { $ast.push: $e.ast }
    }
    if $<flat> {
        my $flat := $<flat>.ast;
        $flat.flat(1);
        $ast.push: $flat;
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
        make self.bind-symbol($<lhs><identifier>.ast.name, $<rhs>.ast);
    }
    elsif $<lhs><postfix> {
        make QAST::Block.new(:blocktype<immediate>,
            QAST::Var.new(:name<$_>, :scope<local>, :decl<var>),
            QAST::Op.new(:op<bind>,
                QAST::Var.new(:name<$_>, :scope<local>),
                $<lhs>[0].ast),
            QAST::Op.new(:op<bindattr>,
                QAST::Var.new(:name<$_>, :scope<local>),
                QAST::Op.new(:op<what>, QAST::Var.new(:name<$_>, :scope<local>)),
                QAST::SVal.new(:value($<lhs><postfix><identifier>.ast.name)),
                $<rhs>.ast));
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

    my $funobj := QAST::Op.new(:op<call>,
        QAST::Op.new(:op<getcurhllsym>, QAST::SVal.new(:value<function>)),
        $block,
        QAST::SVal.new(:value($name)));

    my @ops := [];
    for $<parameter_list>.ast -> $p {
        $block[0].push: $p.ast;
        # Handling arguments with default values is kind of weird, because
        # Python's semantics for them are weird. Instead of being thunks that
        # are evaluated for each call to a function (like in Perl or Lisp),
        # they're evaluated *once*: when the function is bound to its symbol.
        if $p<EXPR> {
            my $default-name := '$default' ~ $*DEFAULTS++;
            my $var := QAST::Var.new(:name($default-name), :scope<lexical>);
            # Add a declaration for the variable holding the precomputed
            # default value to the containing $*BLOCK.
            $*BLOCK[0].push: QAST::Var.new(:name($default-name),
                :scope<lexical>, :decl<var>);
            # Set the default value of the parameter.
            $p.ast.default($var);
            @ops.push: QAST::Op.new(:op<bind>,
                $var,
                $p<EXPR>.ast);
        }
    }

    if $<parameter_list><slurpy> {
        $block[0].push: QAST::Var.new(:name($<parameter_list><slurpy>.ast.name),
            :scope<lexical>, :decl<param>, :slurpy(1));
    }

    @ops.push: self.bind-symbol($name, $funobj);

    make +@ops == 1 ?? @ops[0] !! QAST::Stmts.new(|@ops);
}

method compound-statement:sym<class>($/) {
    my $name := $<identifier>.ast.name;
    my $block := $<new_scope>.ast;

    # Bootstrap classes are created directly from the ClassHOW
    my $bootstrap := QAST::Op.new(:op<callmethod>, :name<new_type>,
        QAST::WVal.new(:value(Snake::Metamodel::ClassHOW)),
        QAST::SVal.new(:value($name), :named<name>));

    # Standard class creation is done by calling the type object, with three
    # arguments. ATM only the first one is actually relevant, but to get it
    # fully properly right it should be three, so we pass three.
    my $inheritance := QAST::Op.new(:op<list>);
    if $<inheritance> {
        for $<inheritance><expression_list>.ast -> $parent {
            $inheritance.push: $parent;
        }
    }

    my $standard := QAST::Op.new(:op<call>,
        QAST::Op.new(:op<getcurhllsym>, QAST::SVal.new(:value<type>)),
        QAST::SVal.new(:value($name)),
        $inheritance,
        QAST::Op.new(:op<null>));

    my $creation := QAST::Op.new(:op<if>,
        QAST::Op.new(:op<isnull>,
            QAST::Op.new(:op<getcurhllsym>, QAST::SVal.new(:value<type>))),
            $bootstrap,
            $standard);

    $block[0].push: QAST::Var.new(:name<$class>, :scope<local>, :decl<param>);
    $block[1].push: QAST::Var.new(:name<$class>, :scope<local>);

    make self.bind-symbol($name, QAST::Op.new(:op<call>, $block, $creation));
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
        $*BLOCK.symbol: $var, :declared(1);
        $*BLOCK[0].push: QAST::Var.new(:name($var), :scope<lexical>, :decl<var>);
    }
}

method special-call($invocant, $special, *@args) {
    QAST::Op.new(:op<call>,
        QAST::Op.new(:op<call>,
            QAST::Op.new(:op<getcurhllsym>,
                QAST::SVal.new(:value<find_special>)),
            $invocant,
            QAST::SVal.new(:value($special))),
        |@args);
}

# Joint method for all the code paths that bind something to a symbol (class,
# def, etc). This is needed because binding has quite different semantics
# inside a class block.
method bind-symbol($symbol, $rhs) {
    if $*IN_CLASS {
        my $class := QAST::Var.new(:name<$class>, :scope<local>);
        return QAST::Op.new(:op<bindattr>,
            $class,
            QAST::Op.new(:op<what>, $class),
            QAST::SVal.new(:value($symbol)),
            $rhs);
    }
    else {
        self.add-declaration($symbol);
        return QAST::Op.new(:op<bind>,
            QAST::Var.new(:name($symbol), :scope<lexical>),
            $rhs);
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
