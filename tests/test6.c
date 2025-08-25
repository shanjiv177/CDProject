// Test Case 6: String and char literals
#include <stdio.h>

int main() {
    char* s1 = "Hello World";
    char* s2 = "Hello \"Quoted\" World";
    char* s3 = "Line1\nLine2";
    char c1 = 'a';
    char c2 = '\n';
    char c3 = '\'';
    
    printf("%s %c\n", s1, c1);
    return 0;
}
