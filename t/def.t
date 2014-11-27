nqp::say("1..2");

def with_3_params(a,b,c):
    nqp::print(a)
    nqp::print(b)
    nqp::say(c)

def with_0_params():
    nqp::say("ok 2");

with_3_params("o","k"," 1");
with_0_params()
