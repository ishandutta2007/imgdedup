BIN=imgdedup
CODESIGN_IDENTITY=Developer ID Application: JESSE GORDON DONAT (NBWN497MH2)
NOTARY_PROFILE=notarytool-profile

.PHONY: all
all: clean test build install

.PHONY: test
test:
	go test ./...

.PHONY: install
install:
	go install ./cmd/imgdedup

.PHONY: clean
clean:
	-rm -rf release dist
	mkdir release dist

release/darwin_amd64/$(BIN):
	env GOOS=darwin GOARCH=amd64 go build -o release/darwin_amd64/$(BIN) ./cmd/imgdedup

release/darwin_arm64/$(BIN):
	env GOOS=darwin GOARCH=arm64 go build -o release/darwin_arm64/$(BIN) ./cmd/imgdedup

release/darwin_universal/$(BIN): release/darwin_amd64/$(BIN) release/darwin_arm64/$(BIN)
	mkdir release/darwin_universal
	lipo -create -output release/darwin_universal/$(BIN) release/darwin_amd64/$(BIN) release/darwin_arm64/$(BIN)

release/linux_amd64/$(BIN):
	env GOOS=linux GOARCH=amd64 go build -o release/linux_amd64/$(BIN) ./cmd/imgdedup

release/freebsd_amd64/$(BIN):
	env GOOS=freebsd GOARCH=amd64 go build -o release/freebsd_amd64/$(BIN) ./cmd/imgdedup

release/windows_amd64/$(BIN):
	env GOOS=windows GOARCH=amd64 go build -o release/windows_amd64/$(BIN).exe ./cmd/imgdedup

.PHONY: build
build: release/darwin_universal/$(BIN) release/linux_amd64/$(BIN) release/freebsd_amd64/$(BIN) release/windows_amd64/$(BIN)

.PHONY: sign
sign: build
	codesign \
		--force \
		--timestamp \
		--options runtime \
		--sign "$(CODESIGN_IDENTITY)" \
		release/darwin_universal/$(BIN)

	codesign --verify --strict --verbose=4 release/darwin_universal/$(BIN)

.PHONY: package
package: sign
	mkdir -p dist
	ditto -c -k --keepParent release/darwin_universal/$(BIN) dist/$(BIN).darwin_universal.zip

.PHONY: notarize
notarize: package
	xcrun notarytool submit dist/$(BIN).darwin_universal.zip \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait

.PHONY: release
release: clean build
	$(MAKE) notarize
	zip -9 -j 'dist/$(BIN).linux_amd64.zip'       release/linux_amd64/$(BIN)
	zip -9 -j 'dist/$(BIN).freebsd_amd64.zip'     release/freebsd_amd64/$(BIN)
	zip -9 -j 'dist/$(BIN).windows_amd64.exe.zip' release/windows_amd64/$(BIN).exe
