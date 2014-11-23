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
        nqp::die("User-defined callables NYI");
    }
}

method new_type(:$name, :@parents) {
    my $type := nqp::newtype(self.new(:$name, :@parents), 'HashAttrStore');
    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), &invocation);
    $type
}

method find_attribute($instance, str $attribute) {
    if nqp::existskey(%!class-attributes, $attribute) {
        %!class-attributes{$attribute};
        # TODO: If it's a callable, wrap it in the appropriate lambda,
        # depending on what kind of callable it is (staticmethod, classmethod,
        # ordinary function).
    }
    else {
        # TODO: Walk inheritance hierarchy (in C3 order) to find attribute in
        # a superclass.
        nqp::die("No attribute $attribute in class $!name");
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
