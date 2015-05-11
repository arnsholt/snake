class Snake::Metamodel::ClassHOW;

has $!name;
has @!parents;
has @!mro;
has %!class-attributes;

sub invocation($invocant, *@args) {
    if !nqp::isconcrete($invocant) {
        my $object := nqp::create($invocant);
        my $ctor := nqp::how($object).find_attribute($object, "__init__", :die(0));
        if !nqp::isnull($ctor) {
            $ctor(|@args);
            # TODO: Fully conformant compilers should check the return value
            # and throw an exception if anything other than None is returned.
        }
        $object
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
    $type.HOW.compose($type);

    nqp::setinvokespec($type, nqp::null(), nqp::null_s(), &invocation);
    nqp::setmethcache($type, %cheat_methods);
    nqp::setmethcacheauth($type, 1);
    nqp::settypecache($type, $type.HOW.parents($type));

    $type
}

method compose($type) {
    @!mro := compute_c3_mro($type)
}

method name() { $!name }
method parents($class, :$local) { $local ?? @!parents !! @!mro }

# Computes C3 MRO.
sub compute_c3_mro($class) {
    my @immediate_parents := $class.HOW.parents($class, :local);

    # Provided we have immediate parents...
    my @result;
    if nqp::elems(@immediate_parents) {
        if nqp::elems(@immediate_parents) == 1 {
            @result := compute_c3_mro(@immediate_parents[0]);
        } else {
            # Build merge list of lineraizations of all our parents, add
            # immediate parents and merge.
            my @merge_list;
            for @immediate_parents {
                nqp::push(@merge_list, compute_c3_mro($_));
            }
            nqp::push(@merge_list, @immediate_parents);
            @result := c3_merge(@merge_list);
        }
    }

    # Put this class on the start of the list, and we're done.
    nqp::unshift(@result, $class);
    return @result;
}

# C3 merge routine.
sub c3_merge(@merge_list) {
    my @result;
    my $accepted;
    my $something_accepted := 0;
    my $cand_count := 0;

    # Try to find something appropriate to add to the MRO.
    for @merge_list {
        my @cand_list := $_;
        if @cand_list {
            my $rejected := 0;
            my $cand_class := @cand_list[0];
            $cand_count := $cand_count + 1;
            for @merge_list {
                # Skip current list.
                unless $_ =:= @cand_list {
                    # Is current candidate in the tail? If so, reject.
                    my $cur_pos := 1;
                    while $cur_pos <= nqp::elems($_) {
                        if $_[$cur_pos] =:= $cand_class {
                            $rejected := 1;
                        }
                        $cur_pos := $cur_pos + 1;
                    }
                }
            }

            # If we didn't reject it, this candidate will do.
            unless $rejected {
                $accepted := $cand_class;
                $something_accepted := 1;
                last;
            }
        }
    }

    # If we never found any candidates, return an empty list.
    if $cand_count == 0 {
        return @result;
    }

    # If we didn't find anything to accept, error.
    unless $something_accepted {
        nqp::die("Could not build C3 linearization: ambiguous hierarchy");
    }

    # Otherwise, remove what was accepted from the merge lists.
    my $i := 0;
    while $i < nqp::elems(@merge_list) {
        my @new_list;
        for @merge_list[$i] {
            unless $_ =:= $accepted {
                nqp::push(@new_list, $_);
            }
        }
        @merge_list[$i] := @new_list;
        $i := $i + 1;
    }

    # Need to merge what remains of the list, then put what was accepted on
    # the start of the list, and we're done.
    @result := c3_merge(@merge_list);
    nqp::unshift(@result, $accepted);
    return @result;
}

method find_attribute($instance, str $attribute, int :$die = 1) {
    if nqp::existskey(%!class-attributes, $attribute) {
        my $attr := %!class-attributes{$attribute};
        if nqp::isconcrete($instance) && nqp::istype($attr, nqp::gethllsym('snake', 'builtin')) {
            $attr := nqp::clone($attr);
            nqp::bindattr($attr, nqp::what($attr), '__self__', $instance);
        }
        $attr
    }
    else {
        # TODO: When we handle multiple inheritance, do proper C3 walk of
        # parents.
        if +@!parents {
            nqp::how(@!parents[0]).find_attribute($instance, $attribute, :$die);
        }
        elsif $die {
            nqp::die("No attribute $attribute in class $!name");
        }
        else {
            nqp::null();
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
