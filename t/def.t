print("1..5");

def with_param(a):
    print(a)

def with_0_params():
    print("ok 2")

def slurpy(*args):
    print("ok")

with_param("ok 1");
with_0_params()
slurpy(1,2,3)
x = [1,2,3]
slurpy(*x)
slurpy(*[1,2,3])

# vim: ft=python
