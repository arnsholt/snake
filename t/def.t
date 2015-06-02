print("1..6");

def with_param(a):
    print(a)

def with_0_params():
    print("ok 2")

def has_default(a="ok 3 - default value"):
    print(a)

def slurpy(*args):
    # No numbering for this, since it's called several times.
    if nqp::iseq_i(nqp::elems(args), 3):
        print("ok - slurpies")
    else:
        print("not ok - slurpies")

with_param("ok 1");
with_0_params()
has_default()
slurpy(1,2,3)
x = [1,2,3]
slurpy(*x)
slurpy(*[1,2,3])

# vim: ft=python
