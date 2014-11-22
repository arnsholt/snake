class Snake::Metamodel::ClassHOW;

has $!name;
has @!parents;

sub invocation($invocant, *@args) {
    if !nqp::isconcrete($invocant) {
        nqp::create($invocant);
        # TODO: Invoke constructors.
    }
    else {
        nqp::die("User-defined callables NYI");
    }
}

method new_type(:$name, :@parents) {
    my $type := nqp::newtype(self.new(:$name, :@parents), 'HashAttrStore');
    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), &invocation);
    $type
}

method find_attribute($instance, str $attribute) {
    nqp::die("ClassHOW.find_attribute NYI");
}

method bind_attribute($instance, str $attribute, $value) {
    if nqp::isconcrete($instance) {
        nqp::bindattr($instance, nqp::what($instance), $attribute, $value);
    }
    else {
        nqp::die("bind_attribute on class objects NYI");
    }
}

# vim: ft=perl6
