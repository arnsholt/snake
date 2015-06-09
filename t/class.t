class C:
    def foo(self, x): print(x)

class D (C):
    def __init__(self, msg): self.msg = msg

print("1..8")
c = C()
print("ok 1 - instantiation")
c.foo("ok 2 - method call on instance")
C.foo(1, "ok 3 - call via type object")

d = D("ok 4 - initializer")
print(d.msg)
d.foo("ok 5 - call from subclass")

class E:
    a = "ok 6 - lookup in class body"
    print(a)

class NonData:
    def __get__(self, instance, owner):
        print("ok 7 - non-data descriptor")
        return "not ok 8 - precedence of instance attribute over non-data descriptor"

class Owner:
    a = NonData()

o = Owner()
o.a
o.a = "ok 8 - precedence of instance attribute over non-data descriptor"
print(o.a)

# vim: ft=python
