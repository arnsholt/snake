use NQPy::Actions;
use NQPy::Compiler;
use NQPy::Grammar;

#NQPy::Grammar.HOW.trace-on(NQPy::Grammar);

my $comp := NQPy::Compiler.new();
$comp.language('nqpy');
$comp.parsegrammar(NQPy::Grammar);
$comp.parseactions(NQPy::Actions);

sub MAIN(*@args) {
    $comp.command_line(@args[0], :encoding<utf8>);
}

# vim: ft=perl6
