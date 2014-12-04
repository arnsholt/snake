use Snake::Actions;
use Snake::Compiler;
use Snake::Grammar;
use Snake::ModuleLoader;

use Snake::Metamodel::ClassHOW;

#Snake::Grammar.HOW.trace-on(Snake::Grammar);

my $comp := Snake::Compiler.new();
$comp.language('snake');
$comp.parsegrammar(Snake::Grammar);
$comp.parseactions(Snake::Actions);

my @options := $comp.commandline_options();
@options.push: 'setting=s';

nqp::bindhllsym('snake', 'builtin', Snake::Metamodel::BuiltinHOW.new_type());

sub MAIN(@args) {
    $comp.command_line(@args, :encoding<utf8>);
}

# vim: ft=perl6
