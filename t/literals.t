print("1..11")

x = []
print("ok 1 - creating empty list")
x = [1, 2, 3]
print("ok 2 - creating non-empty list")
x = [nqp::add_i(i, j) for i in x for j in [3]]
print("ok 3 - list comprehension")
# XXX: Kind of ugly printing here, since we don't have string concatenation or
# formatting yet.
nqp::print("ok ")
nqp::print(nqp::atpos(x, 0))
print(" - comprehended value")
nqp::print("ok ")
nqp::print(nqp::atpos(x, 1))
print(" - comprehended value")
nqp::print("ok ")
nqp::print(nqp::atpos(x, 2))
print(" - comprehended value")

x = {}
print("ok 7 - creating empty hash")
x = {1: 2}
print("ok 8 - creating non-empty hash")

x = ()
print("ok 9 - creating empty tuple")
x = (1,)
print("ok 10 - creating single-element tuple")
x = (1, 2, 3)
print("ok 11 - creating multi-element tuple")

# vim: ft=python
