# C Language Lexical Analyzer

This project implements a lexical analyzer (scanner) for the C programming language using Flex.

## Project Structure

```
/
├── src/         # Source code
│   └── scanner.l   # Main Flex specification file
├── tests/       # Test cases
│   ├── test1.c     # Basic C code
│   ├── test2.c     # Invalid tokens
│   ├── test3.c     # Comments
│   ├── test4.c     # Preprocessor directives
│   ├── test5.c     # String literals
│   └── test6.c     # Complex string/char literals
├── bin/         # Compiled binaries
├── build/       # Build artifacts
├── docs/        # Documentation
│   └── C_Scanner_Documentation.md  # Detailed scanner documentation
└── Makefile     # Build automation
```

## Building the Project

To build the scanner:

```bash
make
```

## Running Tests

To run all tests:

```bash
make test
```

To run a specific test:

```bash
make run-test TEST=test1.c
```

## Features

- Recognition of all C tokens (keywords, identifiers, literals, operators, etc.)
- Symbol table with O(1) lookup using hash table
- Constant table with variable name tracking
- Error detection and reporting
- Support for comments, strings, and character literals
- Function call and parameter tracking

## Documentation

See the [detailed documentation](docs/C_Scanner_Documentation.md) for a complete description of the scanner implementation, DFA diagrams, test cases, and assumptions.
