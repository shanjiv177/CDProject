CC = gcc
FLEX = flex
CFLAGS = -Wall -g
LDFLAGS = -lfl

# Directories
SRC_DIR = src
TEST_DIR = tests
BIN_DIR = bin
BUILD_DIR = build

# Files
SCANNER_SRC = $(SRC_DIR)/scanner.l
SCANNER_C = $(BUILD_DIR)/lex.yy.c
SCANNER_BIN = $(BIN_DIR)/scanner

# Test files
TEST_FILES = $(wildcard $(TEST_DIR)/*.c)

# Make sure build and bin directories exist
$(shell mkdir -p $(BUILD_DIR) $(BIN_DIR))

# Default target
all: $(SCANNER_BIN)

# Build the scanner
$(SCANNER_BIN): $(SCANNER_C)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Generate C code from the flex file
$(SCANNER_C): $(SCANNER_SRC)
	$(FLEX) -o $@ $<

# Clean build files
clean:
	rm -f $(SCANNER_C) $(SCANNER_BIN)

# Run tests
test: $(SCANNER_BIN)
	@echo "Running tests..."
	@for test in $(TEST_FILES); do \
		echo "\n=== Running test: $$test ==="; \
		$(SCANNER_BIN) $$test; \
	done

# Run a specific test
# Usage: make run-test TEST=test1.c
run-test: $(SCANNER_BIN)
	@echo "Running test: $(TEST_DIR)/$(TEST)"
	$(SCANNER_BIN) $(TEST_DIR)/$(TEST)

.PHONY: all clean test run-test
