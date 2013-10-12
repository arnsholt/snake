NQP=../nqp/nqp
PARROT=../nqp/install/bin/parrot
PBC_TO_EXE=../nqp/install/bin/pbc_to_exe

PBCS=blib/Snake/Actions.pbc \
	 blib/Snake/Compiler.pbc \
	 blib/Snake/Grammar.pbc \

snake: $(PBCS) src/snake.nqp
	$(NQP) --target=pir src/snake.nqp | $(PARROT) -o blib/snake.pbc -
	$(PBC_TO_EXE) blib/snake.pbc
	cp blib/snake $@

blib/%.pbc: src/%.nqp
	$(NQP) --target=pir $< | $(PARROT) -o $@ -

clean:
	rm -f $(PBCS)

test:
	prove -r --exec ./snake t/sanity/*.t
