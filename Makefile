all: fmt build test
build:
	zig build
fmt:
	zig fmt src
	zig fmt build.zig

test:
	zig build test-quick
ifeq ($(RUN_SLOW_TESTS), true)
	zig build -Doptimize=ReleaseFast test-slow
endif 

run:
	zig build run

explore:
	zig test src/explore.zig