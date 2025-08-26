#include <stdio.h>

/* Simple comment */

/* This is a 
   multiline comment */

/* This comment contains a nested comment start token
   /* This is a nested comment which should trigger an error */
   End of outer comment */

int main() {
    printf("Testing comments\n");
    // Single line comment
    
    return 0;
}
