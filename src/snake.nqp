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
        my $self := nqp::getattr($invocant, $what, '__self__');
        if $self {
            nqp::unshift(@args, $self);
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
nqp::settypecache($builtin, [$builtin]);

nqp::bindhllsym('snake', 'builtin', $builtin);

my sub find_special($invocant, str $attr) {
    my $type := nqp::getattr($invocant, nqp::what($invocant), '__class__');
    my @mro := nqp::getattr($type, nqp::what($type), '__mro__');
    for @mro -> $parent {
        my $value := nqp::getattr($parent, nqp::what($parent), $attr);
        # TODO: If it's a built-in, do the whole clone and __self__ bind
        # thing. Further down the line, handle descriptors too.
        if !nqp::isnull($value) {
            if nqp::istype($value, nqp::gethllsym('snake', 'builtin')) {
                $value := nqp::clone($value);
                nqp::bindattr($value, nqp::what($value), '__self__', $invocant);
            }
            return $value;
        }
        #return $value if !nqp::isnull($value);
    }
    my $name := nqp::getattr($type, nqp::what($type), '__name__');
    nqp::die("Couldn't find $attr in $name");
}
nqp::bindhllsym('snake', 'find_special', &find_special);

sub MAIN(@args) {
    $comp.command_line(@args, :encoding<utf8>);
}

# vim: ft=perl6
