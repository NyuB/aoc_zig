![CI status badge](https://github.com/NyuB/aoc_zig/actions/workflows/ci.yml/badge.svg)

# Advent of code 2023 with Zig

Learning material, problems solutions and some side exploration with the language

## Setup

Download Zig from an official release link here => https://ziglang.org/download/

This repository is using Zig **0.11.0**

## Run tests

To run all tests:

```bash
# Omitting the RUN_SLOW_TESTS flag will skip the slower tests
make test RUN_SLOW_TESTS=true
```

To run a single test: 

```bash
# Replace yyyy and dd with year and day of the relevant AoC problem
zig test --test-filter "src\aoc_yyyy_dd.zig"
```

## Format code

```bash
make fmt
```

## Generate a problem template

```bash
# Replace yyyy and dd with year and day of the AoC problem you want to generate a template for
zig build problem_template -- yyyy dd
```
