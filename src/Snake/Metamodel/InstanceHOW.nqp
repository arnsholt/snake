class Snake::Metamodel::InstanceHOW;

method new_type() {
    nqp::newtype(self.new, 'HashAttrStore');
}

# vim: ft=perl6
