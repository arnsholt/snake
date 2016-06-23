print("1..11")

def isequal_i(a, b):
    if nqp::iseq_i(a, b):
        print("ok")
    else:
        print("not ok")

isequal_i(1, 1)
isequal_i(0x1, 1)
isequal_i(0x1f, 31)
isequal_i(0X1f, 31)
isequal_i(12, 12)


def isequal_n(a, b):
    if nqp::iseq_n(a, b):
        print("ok")
    else:
        print("not ok")

isequal_n(10., 10)
isequal_n(0e0, 0)
isequal_n(.001, 0.001)
isequal_n(010.2, 10.2)
isequal_n(02e02, 200)

# test using GREEK ANO TELEIA as part of an identifier
foo·bar = "ok 11"
print(foo·bar)
