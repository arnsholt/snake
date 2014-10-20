nqp::say('1..2')

if 1:
    if 0:
        nqp::say("BAIL OUT!")
else:
    nqp::print('not ')

nqp::say('ok 1 - else attachment')

if 0:
    nqp::say("BAIL OUT!")
elif 1:
    nqp::say("ok 2 - elif")
else:
    nqp::say("BAIL OUT!")
