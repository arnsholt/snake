class C:
    def foo(self, x): print(x)

class D (C):
    def __init__(self, msg): self.msg = msg

print("1..5")
c = C()
print("ok 1 - instantiation")
c.foo("ok 2 - method call on instance")
C.foo(1, "ok 3 - call via type object")

d = D("ok 4 - initializer")
print(d.msg)
d.foo("ok 5 - call from subclass")

# vim: ft=python
