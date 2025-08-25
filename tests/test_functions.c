// Test Case: Custom functions with parameters and calls
#include <stdio.h>

// Simple addition function
int add(int a, int b) {
    return a + b;
}

// Function with multiple parameters and local variables
float calculate(int x, float y, char op) {
    float result = 0.0;
    
    if (op == '+') {
        result = x + y;
    } else if (op == '-') {
        result = x - y;
    } else if (op == '*') {
        result = x * y;
    } else if (op == '/') {
        if (y != 0) {
            result = x / y;
        }
    }
    
    return result;
}

// Main function calling the custom functions
int main() {
    int sum = add(5, 10);
    printf("Sum: %d\n", sum);
    
    float calc_result = calculate(20, 5.5, '+');
    printf("Calculation result: %.2f\n", calc_result);
    
    // Testing another operation
    calc_result = calculate(20, 5.5, '*');
    printf("Calculation result: %.2f\n", calc_result);
    
    return 0;
}
