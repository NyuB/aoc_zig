all: fmt test

fmt:
	zig fmt src
	zig fmt build.zig

test:
	zig build test

run:
	zig build run

explore:
	zig test src/explore.zig