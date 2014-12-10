class Snake::Metamodel::ClassHOW;

has $!name;
has @!parents;
has %!class-attributes;

sub invocation($invocant, *@args) {
    if !nqp::isconcrete($invocant) {
        nqp::create($invocant);
        # TODO: Invoke constructors.
    }
    else {
        my $attr := nqp::how($invocant).find_attribute($invocant, "__call__");
        $attr(|@args);
    }
}

my %cheat_methods := nqp::hash(
    'Str', -> *@_ { "<python>" },
);
method new_type(:$name, :@parents) {
    my $type := nqp::newtype(self.new(:$name, :@parents), 'HashAttrStore');

    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), &invocation);
    nqp::setmethcache($type, %cheat_methods);
    nqp::setmethcacheauth($type, 1);

    $type
}

method add_parents(*@parents) {
    for @parents -> $p {
        # Make sure $p is a valid superclass (ie. a Python type object). That
        # means it has to be a non-concrete object, whose HOW is a ClassHOW.
        if nqp::isconcrete($p) || !nqp::istype(nqp::how($p), Snake::Metamodel::ClassHOW) {
            nqp::die("Classes can only inherit from valid type objects.");
        }
        nqp::push(@!parents, $p);
    }
    if +@!parents > 1 { nqp::die("Multiple inheritance NYI"); }
}

method find_attribute($instance, str $attribute) {
    if nqp::existskey(%!class-attributes, $attribute) {
        my $attr := %!class-attributes{$attribute};
        # XXX: nqp::istype($attr, nqp::getcurhllsym('builtin')) doesn't work
        # here. Not entirely sure why.
        if nqp::isconcrete($instance) && nqp::istype(nqp::how($attr), Snake::Metamodel::BuiltinHOW) {
            $attr := nqp::clone($attr);
            nqp::bindattr($attr, nqp::what($attr), '__self__', $instance);
        }
        $attr
    }
    else {
        # TODO: When we handle multiple inheritance, do proper C3 walk of
        # parents.
        if +@!parents {
            nqp::how(@!parents[0]).find_attribute($instance, $attribute);
        }
        else {
            nqp::die("No attribute $attribute in class $!name");
        }
    }
}

method bind_attribute($instance, str $attribute, $value) {
    if nqp::isconcrete($instance) {
        nqp::bindattr($instance, nqp::what($instance), $attribute, $value);
    }
    else {
        %!class-attributes{$attribute} := $value;
    }
}

# vim: ft=perl6
