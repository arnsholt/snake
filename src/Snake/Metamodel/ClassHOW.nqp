class Snake::Metamodel::ClassHOW;

has $!name;

sub invocation($invocant, *@args) {
    nqp::die("Can't call NQP type object for {$invocant.name}")
        if !nqp::isconcrete($invocant);
    my $call := nqp::gethllsym('snake', 'find_special')($invocant, '__call__');
    $call(|@args);
}

my %cheat_methods := nqp::hash(
    'Str', -> *@_ {
        my $self := @_[0];
        my $name := nqp::getattr($self, nqp::what($self), '__name__');
        "<snake NQP type for: $name>"
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
