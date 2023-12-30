ZIG=zig

all: fmt build test

build:
	$(ZIG) build

fmt:
	$(ZIG) fmt src
	$(ZIG) fmt build.zig

test:
	$(ZIG) build test-quick
ifeq ($(RUN_SLOW_TESTS), true)
	$(ZIG) build -Doptimize=ReleaseFast test-slow
endif 

run:
	$(ZIG) build run

explore:
	$(ZIG) test src/explore.zig