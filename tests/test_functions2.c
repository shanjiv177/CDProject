// Test Case: Improved function tests
#include <stdio.h>

// Function with parameters and return value
int multiply(int x, int y) {
    return x * y;
}

// Function with no parameters
void printMessage() {
    printf("Hello from function!\n");
}

// Function with array parameter
int sumArray(int arr[], int size) {
    int total = 0;
    for (int i = 0; i < size; i++) {
        total += arr[i];
    }
    return total;
}

int main() {
    // Simple function call with integer constants
    int product = multiply(6, 7);
    
    // Function call with variables
    int a = 10;
    int b = 5;
    int result = multiply(a, b);
    
    // Function with no arguments
    printMessage();
    
    // Function with array
    int numbers[] = {1, 2, 3, 4, 5};
    int sum = sumArray(numbers, 5);
    
    printf("Results: %d, %d, %d\n", product, result, sum);
    
    return 0;
}
