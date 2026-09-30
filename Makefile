APP := build/ScreenRecord.app

.PHONY: app run clean

app:
	./scripts/build-app.sh

run: app
	open $(APP)

clean:
	rm -rf .build build
