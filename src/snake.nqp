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

my sub builtin_call($invocant, *@args) {
    if nqp::isconcrete($invocant) {
        my $what := nqp::what($invocant);
        my $code := nqp::getattr($invocant, $what, '__code__');
        if nqp::getattr($invocant, $what, '__self__') {
            nqp::unshift(@args, $invocant);
        }
        nqp::call($code, |@args);
    }
    else {
        nqp::die("Wrong number of arguments when creating built-in (got {+@args})") if +@args != 2;
        my $f := nqp::create($invocant);
        nqp::bindattr($f, $invocant, '__code__', @args[0]);
        nqp::bindattr($f, $invocant, '__name__', @args[1]);
        $f
    }
}

my $builtin := Snake::Metamodel::ClassHOW.new_type(:name("<builtin>"));
nqp::setinvokespec($builtin, nqp::null(), nqp::null(), &builtin_call);

nqp::bindhllsym('snake', 'builtin', $builtin);

sub MAIN(@args) {
    $comp.command_line(@args, :encoding<utf8>);
}

# vim: ft=perl6
