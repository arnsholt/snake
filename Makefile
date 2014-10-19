PREFIX=../nqp/install
NQP=$(PREFIX)/bin/nqp-m
MOAR=$(PREFIX)/bin/moar

MOARS=blib/Snake/Actions.moarvm \
         blib/Snake/Compiler.moarvm \
         blib/Snake/Grammar.moarvm \
         blib/snake.moarvm

.PHONY: all

all: $(MOARS)

blib/%.moarvm: src/%.nqp
	$(NQP) --target=mbc --output=$@ $<

test: all
	prove -r --exec ./snake t/sanity/*.t

clean:
	-rm $(MOARS)
