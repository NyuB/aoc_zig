all: fmt test

fmt:
	zig fmt src

test:
	zig build test