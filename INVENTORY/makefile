.PHONY: clean

GENERATED = generated/gen-lab-config.json  generated/gen-tb-config.json

run: $(GENERATED)
	@echo "[INVENTORY] All generated files are up to date."

$(GENERATED):
	@echo "[INVENTORY] Running init.sh to generate outputs..." >&2
	@mkdir -p generated
	@./init.sh

clean:
	@rm -fr generated

