class Snake::Metamodel::ClassHOW;

has $!name;
has @!parents;

method new_type(:$name, :$instance-type, :@parents) {
    my $type := nqp::newtype(self.new(:$name, :@parents), 'HashAttrStore');
    my $code := sub ($invoked, *@args) {
        # TODO: Invoke constructor. This code should probably be more complex
        # to do everything right. For now, we keep it simple. With a bit of
        # luck, once we something resembling a setting library, much of the
        # work can be done in Python code.
        nqp::create($instance-type);
    };
    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), $code);
    $type
}

# vim: ft=perl6
