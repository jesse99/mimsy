# There is a custom build phase in the project which will build
# the go extensions and install them. But, like the lua extensions,
# they are only installed if the build number is incremented. Also
# XCode does not have syntax highlighting for lua or go and does
# not parse errors from lua or go.
#
# Because of the above it's usually simplest to use Mimsy to edit
# and build extensions.

wd := $(shell pwd)

all: install

.PHONY: install
install:
	export GOPATH=$(wd)/GoExtensions
	cd GoExtensions/src && go install *
	rsync -ar --existing ./GoExtensions/bin/ ~/Library/Application\ Support/Mimsy/extensions
	rsync -ar --existing ./Mimsy/extensions/ ~/Library/Application\ Support/Mimsy/extensions

