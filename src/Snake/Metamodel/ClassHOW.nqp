class Snake::Metamodel::ClassHOW {
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
}

class Snake::Metamodel::BuiltinHOW is Snake::Metamodel::ClassHOW {
    sub invocation($invocant, *@args) {
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

    method new_type() {
        my $type := nqp::newtype(self.new, 'HashAttrStore');
        nqp::setinvokespec($type, nqp::null(), nqp::null(), &invocation);
        $type;
    }
}

# vim: ft=perl6
