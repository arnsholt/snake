class Snake::Metamodel::ClassHOW;

has $!name;

sub invocation($invocant, *@args) {
    nqp::die("Can't call NQP type object for {$invocant.name}")
        if !nqp::isconcrete($invocant);
    my $call := nqp::gethllsym('snake', 'find_special')($invocant, '__call__');
    $call(|@args);
}

my %cheat_methods := nqp::hash(
    'Str', -> $self {
        if nqp::isconcrete($self) {
            my $class := nqp::getattr($self, nqp::what($self), '__class__');
            "<{nqp::getattr($class, nqp::what($class), '__name__')} instance>"
        }
        else {
            "<NQP type for {nqp::how($self).name}>"
        }
    },
);
method new_type(:$name, :@mro) {
    my $type := nqp::newtype(self.new(:$name), 'HashAttrStore');

    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), &invocation);
    nqp::setmethcache($type, %cheat_methods);
    nqp::setmethcacheauth($type, 1);
    nqp::settypecache($type, @mro);

    $type
}

method name() { $!name }

# vim: ft=perl6
