class C:
    def foo(self, x): print(x)

print("1..3")
c = C()
print("ok 1 - instantiation")
c.foo("ok 2 - method call on instance")
C.foo(1, "ok 3 - call via type object")
