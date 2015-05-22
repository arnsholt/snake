print("1..3");

def with_param(a):
    print(a)

def with_0_params():
    print("ok 2")

def slurpy(*args):
    print("ok 3")

with_param("ok 1");
with_0_params()
slurpy(1,2,3)

# vim: ft=python
