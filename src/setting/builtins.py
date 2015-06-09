# We'll need this round about, so let's store it somewhere more convenient.
_find_special = nqp::getcurhllsym('find_special')

# Create bootstrap NQP type objects for object and type.
class object: pass
class type: pass
nqp::bindcurhllsym('object_type', object)
nqp::settypecache(type, [object, type])

# Create Python type objects. Prefixed so that we don't overwrite the NQP
# objects before we've stashed them in the Python ones.
_object = nqp::create(type)
_type = nqp::create(type)

# Wire up the `type` object.
_type.__nqptype__ = type
_type.__class__ = _type
_type.__bases__ = (_object,)
_type.__mro__ = (_type, _object)
_type.__name__ = "type"

def __call__(self, *args):
    if nqp::eqaddr(self, nqp::getcurhllsym('type')):
        if nqp::iseq_i(nqp::elems(args), 1):
            nqp::die("Single-argument form of type() NYI")
        elif nqp::iseq_i(nqp::elems(args), 3):
            name = nqp::atpos(args, 0)
            bases = nqp::atpos(args, 1)
            namespace = nqp::atpos(args, 2) # Ignored for now

            parents = nqp::elems(bases)
            if nqp::iseq_i(parents, 0): bases = [nqp::getcurhllsym('object')]
            elif nqp::isgt_i(parents, 1):
                nqp::die("Multiple inheritance NYI")

            typeobj = nqp::create(self.__nqptype__)
            # TODO: Multiple inheritance
            parentmro = nqp::atpos(bases, 0).__mro__
            mro = [typeobj]
            for parent in parentmro:
                nqp::push(mro, parent)
            typeobj.__name__ = name
            typeobj.__class__ = self
            typeobj.__nqptype__ = nqp::callmethod(
                    nqp::how(self),
                    'new_type',
                    name=name,
                    mro=[parent.__nqptype__ for parent in parentmro])
            typeobj.__bases__ = bases
            typeobj.__mro__ = mro
            return typeobj
        else:
            nqp::die("type() takes one or three arguments")
    else:
        instance = self.__new__(self, *args)
        # TODO: Check type of return value.
        # TODO: Call __init__
        return instance
_type.__call__ = __call__

def __getattribute__(self, name):
    mro = nqp::getattr(self, nqp::what(self), '__mro__')
    for p in mro:
        value = nqp::getattr(p, nqp::what(p), name)
        if not nqp::isnull(nqp::getlex('value')):
            break

    if not nqp::isnull(nqp::getlex('value')):
        # Return early for non-Python things.
        if not nqp::isconcrete(value) or not nqp::istype(value,
                nqp::getcurhllsym('object_type')):
            return value
        get = _find_special(value, '__get__')
        if not nqp::isnull(nqp::getlex('get')):
            value = get(None, self)
        return value
_type.__getattribute__ = __getattribute__

# Finally, bind the Python object to the correct lexical. We also stash it
# away as an hllsym, as the default metaclass lookup is always the builtin
# `type`, not the lexical one.
type = _type
nqp::bindcurhllsym('type', type)

# Wire up the `object` type.
_object.__nqptype__ = object
_object.__class__ = _type
_object.__bases__ = ()
_object.__mro__ = (_object,)
_object.__name__ = "object"

# The behaviour of object.__new__ and object.__init__ are not obvious from
# black-box inspection at the REPL (at least they weren't to me). We therefore
# include this exegetic comment from the CPython sources:
#
# You may wonder why object.__new__() only complains about arguments
#    when object.__init__() is not overridden, and vice versa.
#
#    Consider the use cases:
#
#    1. When neither is overridden, we want to hear complaints about
#       excess (i.e., any) arguments, since their presence could
#       indicate there's a bug.
#
#    2. When defining an Immutable type, we are likely to override only
#       __new__(), since __init__() is called too late to initialize an
#       Immutable object.  Since __new__() defines the signature for the
#       type, it would be a pain to have to override __init__() just to
#       stop it from complaining about excess arguments.
#
#    3. When defining a Mutable type, we are likely to override only
#       __init__().  So here the converse reasoning applies: we don't
#       want to have to override __new__() just to stop it from
#       complaining.
#
#    4. When __init__() is overridden, and the subclass __init__() calls
#       object.__init__(), the latter should complain about excess
#       arguments; ditto for __new__().
#
#    Use cases 2 and 3 make it unattractive to unconditionally check for
#    excess arguments.  The best solution that addresses all four use
#    cases is as follows: __init__() complains about excess arguments
#    unless __new__() is overridden and __init__() is not overridden
#    (IOW, if __init__() is overridden or __new__() is not overridden);
#    symmetrically, __new__() complains about excess arguments unless
#    __init__() is overridden and __new__() is not overridden
#    (IOW, if __new__() is overridden or __init__() is not overridden).
def __new__(cls, *args):
    # TODO: Complain about args if len(args) > 0 and cls.__init__ ==
    # object.__init__ or cls.__new__ != object.__new__
    i = nqp::create(cls.__nqptype__)
    i.__class__ = cls
    _find_special(i, '__init__')(*args)
    return i
__new__.__static__ = 1
_object.__new__ = __new__

def __init__(self, *args):
    # TODO: Complain about args if len(args) > 0 and self.__class__.__new__ ==
    # object.__new__ or self.__class__.__init__ != object.__init__
    pass
_object.__init__ = __init__

def __getattribute__(self, name):
    # We start by walking the MRO, because data descriptors (things with both
    # __get__ and __set__) override instance attributes.
    cls = nqp::getattr(self, nqp::what(self), "__class__")
    mro = nqp::getattr(cls, nqp::what(cls), "__mro__")
    for p in mro:
        inparent = nqp::getattr(p, nqp::what(p), name)
        if not nqp::isnull(nqp::getlex('inparent')):
            break

    if not nqp::isnull(nqp::getlex('inparent')) and nqp::isconcrete(inparent) \
            and nqp::istype(inparent, nqp::getcurhllsym('object_type')):
        get = _find_special(inparent, '__get__')
        set = _find_special(inparent, '__set__')
        if not nqp::isnull(nqp::getlex('get')) and not nqp::isnull(nqp::getlex('set')):
            # TODO
            nqp::die("Data descriptors NYI")

    inself = nqp::getattr(self, nqp::what(self), name)
    if not nqp::isnull(nqp::getlex('inself')):
        return inself
    elif not nqp::isnull(nqp::getlex('inparent')):
        if not nqp::isnull(nqp::getlex('get')):
            inparent = get(self, cls)
        return inparent

    nqp::die(nqp::concat("No such attribute: ", name))
_object.__getattribute__ = __getattribute__

# Then bind it to the lexical, and stash it as an hllsym for the same reasons
# as for `type`.
object = _object
nqp::bindcurhllsym('object', object)

class NoneType: pass
None = NoneType()
nqp::bindcurhllsym('None', None)
def __new__(cls):
    return nqp::getcurhllsym('None')
NoneType.__new__  = __new__

# Until now, functions have been created directly from the NQP type object.
# Fix that, and set __class__ attribute on the functions we've already
# created.
class _builtin:
    def __init__(self, code, name):
        self.__code__ = code
        self.__name__ = name

    def __get__(self, instance, owner):
        if instance is None or not nqp::isnull(nqp::getattr(self,
                nqp::what(self), '__static__')):
            return self
        clone = nqp::clone(self)
        clone.__self__ = instance
        return clone
_builtin.__nqptype__ = nqp::getcurhllsym('function')
nqp::settypecache(_builtin.__nqptype__, [object.__nqptype__, _builtin.__nqptype__])
nqp::getcurhllsym('builtin-fixup')(_builtin)
nqp::bindcurhllsym('function', _builtin)

def print(msg):
    nqp::say(msg)

def isinstance(o, typeinfo):
    # TODO: `typeinfo` can be either a type object or a tuple of typeobjects
    # (or tuples of type objects, etc.).
    # TODO: Throw exception if bad arguments.
    return nqp::istype(o, typeinfo.__nqptype__)

YOU_ARE_HERE
