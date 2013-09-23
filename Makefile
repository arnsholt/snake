NQP=../nqp/nqp
PARROT=../nqp/install/bin/parrot
PBC_TO_EXE=../nqp/install/bin/pbc_to_exe

PBCS=blib/NQPy/Actions.pbc \
	 blib/NQPy/Compiler.pbc \
	 blib/NQPy/Grammar.pbc \
	 blib/nqpy.pbc

nqpy: $(PBCS)
	$(PBC_TO_EXE) blib/nqpy.pbc
	cp blib/nqpy $@

blib/%.pbc: src/%.nqp
	$(NQP) --target=pir $< | $(PARROT) -o $@ -

clean:
	rm -f $(PBCS)
