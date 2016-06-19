PREFIX=../nqp/install
NQP=$(PREFIX)/bin/nqp-m
MOAR=$(PREFIX)/bin/moar

MOARS=blib/Snake/Actions.moarvm \
         blib/Snake/Compiler.moarvm \
         blib/Snake/Grammar.moarvm \
         blib/Snake/ModuleLoader.moarvm \
         blib/Snake/World.moarvm \
         blib/Snake/Metamodel/ClassHOW.moarvm \
         blib/snake.moarvm

.PHONY: all

all: $(MOARS) blib/SNAKE.setting.moarvm

blib/%.moarvm: src/%.nqp
	$(NQP) --target=mbc --output=$@ $<

blib/SNAKE.setting.moarvm: src/setting/builtins.py $(MOARS)
	./snake --setting=NULL --target=mbc --output=$@ $<

blib/Snake/World.moarvm: src/Snake/World.nqp blib/Snake/ModuleLoader.moarvm

blib/Snake/Actions.moarvm: src/Snake/Actions.nqp blib/Snake/Metamodel/ClassHOW.moarvm

blib/Snake/Grammar.moarvm: src/Snake/Grammar.nqp blib/Snake/Actions.moarvm blib/Snake/ModuleLoader.moarvm blib/Snake/World.moarvm

blib/snake.moarvm: blib/Snake/Actions.moarvm blib/Snake/Compiler.moarvm blib/Snake/Grammar.moarvm blib/Snake/ModuleLoader.moarvm blib/Snake/Metamodel/ClassHOW.moarvm

test: all
	prove -r --exec ./snake t/sanity/*.t t/*.t

clean:
	-rm $(MOARS)
