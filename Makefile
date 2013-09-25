NQP=../nqp/nqp
PARROT=../nqp/install/bin/parrot
PBC_TO_EXE=../nqp/install/bin/pbc_to_exe

PBCS=blib/NQPy/Actions.pbc \
	 blib/NQPy/Compiler.pbc \
	 blib/NQPy/Grammar.pbc \

nqpy: $(PBCS) src/nqpy.nqp
	$(NQP) --target=pir src/nqpy.nqp | $(PARROT) -o blib/nqpy.pbc -
	$(PBC_TO_EXE) blib/nqpy.pbc
	cp blib/nqpy $@

blib/%.pbc: src/%.nqp
	$(NQP) --target=pir $< | $(PARROT) -o $@ -

clean:
	rm -f $(PBCS)
