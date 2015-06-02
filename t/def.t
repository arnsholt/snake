print("1..6");

def with_param(a):
    print(a)

def with_0_params():
    print("ok 2")

def has_default(a="ok 3 - default value"):
    print(a)

def slurpy(*args):
    print("ok")

with_param("ok 1");
with_0_params()
has_default()
slurpy(1,2,3)
x = [1,2,3]
slurpy(*x)
slurpy(*[1,2,3])

# vim: ft=python
