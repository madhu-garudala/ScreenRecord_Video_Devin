APP := build/Recordly.app
DIST_ZIP := dist/Recordly.zip
INSTALL_DIR := /Applications

.PHONY: app run install dist icons clean

app:
	./scripts/build-app.sh

icons:
	swift scripts/render-icons.swift

run: app
	open $(APP)

install: app
	cp -R $(APP) $(INSTALL_DIR)/

dist: app
	mkdir -p dist
	rm -f $(DIST_ZIP)
	ditto -c -k --keepParent $(APP) $(DIST_ZIP)
	@echo "Wrote $(DIST_ZIP) — share it with other Macs (see README for the one-time security step)."

clean:
	rm -rf .build build dist
