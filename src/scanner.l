%{
/* Mini Project Phase 1: Scanner for C Language */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

/* ---------------- Utilities ---------------- */

static char* xstrdup(const char* s) {
    if (!s) {
        return NULL;
    }
    size_t n = strlen(s) + 1;
    char* p = (char*)malloc(n);
    if (p) {
        memcpy(p, s, n);
    }
    return p;
}

static char* trim(char* s) {
    if (!s) {
        return s;
    }
    size_t n = strlen(s);
    size_t i = 0;
    while (i < n && isspace((unsigned char)s[i])) {
        i++;
    }
    size_t j = n;
    while (j > i && isspace((unsigned char)s[j - 1])) {
        j--;
    }
    size_t m = j - i;
    memmove(s, s + i, m);
    s[m] = '\0';
    return s;
}

/* ---------------- Symbol Table ---------------- */

typedef struct Symbol {
    char* name;
    char* type;         
    char* dimensions;   
    int   frequency;    
    char* return_type;  
    char* param_lists;  
    int   is_function;  
    struct Symbol* next;
} Symbol;

#define SYM_HASH_SIZE 211
static Symbol* symtab[SYM_HASH_SIZE];

static unsigned long hash_function(const char* str) {
    unsigned long hash = 5381;
    int c;
    while ((c = (unsigned char) *str++)) {
        hash = ((hash << 5) + hash) + c; 
    }
    return hash;
}

static Symbol* sym_lookup(const char* name) {
    unsigned long h = hash_function(name) % SYM_HASH_SIZE;
    Symbol* s = symtab[h];
    while (s) {
        if (strcmp(s->name, name) == 0) {
            return s;
        }
        s = s->next;
    }
    return NULL;
}

static Symbol* sym_insert(const char* name) {
    unsigned long h = hash_function(name) % SYM_HASH_SIZE;
    Symbol* s = (Symbol*)calloc(1, sizeof(Symbol));
    s->name = xstrdup(name);
    s->frequency = 0;
    s->next = symtab[h];
    symtab[h] = s;
    return s;
}

static Symbol* sym_touch(const char* name) {
    Symbol* s = sym_lookup(name);
    if (!s) {
        s = sym_insert(name);
    }
    s->frequency++;
    return s;
}

static void sym_set_type(Symbol* s, const char* type) {
    if (!s) return;
    if (s->type) free(s->type);
    s->type = xstrdup(type);
}

static void sym_set_return(Symbol* s, const char* r) {
    if (!s) return;
    if (s->return_type) free(s->return_type);
    s->return_type = xstrdup(r);
}

static void sym_append_dims(Symbol* s, const char* dims) {
    if (!s || !dims) return;
    size_t old = s->dimensions ? strlen(s->dimensions) : 0;
    size_t add = strlen(dims);
    char* p = (char*)malloc(old + add + 1);
    if (!p) return;
    if (old) {
        memcpy(p, s->dimensions, old);
        free(s->dimensions);
    }
    memcpy(p + old, dims, add);
    p[old + add] = '\0';
    s->dimensions = p;
}

static void sym_append_params(Symbol* s, const char* params) {
    if (!s || !params) return;
    const char* sep = s->param_lists ? " ; " : "";
    size_t old = s->param_lists ? strlen(s->param_lists) : 0;
    size_t add = strlen(sep) + strlen(params);
    char* p = (char*)malloc(old + add + 1);
    if (!p) return;
    if (old) {
        memcpy(p, s->param_lists, old);
        free(s->param_lists);
    }
    memcpy(p + old, sep, strlen(sep));
    memcpy(p + old + strlen(sep), params, strlen(params));
    p[old + add] = '\0';
    s->param_lists = p;
}

/* ---------------- Constant Table ---------------- */

typedef struct Constant {
    char* var_name; 
    int   line;
    char* value;
    char* type; 
} Constant;

static Constant* consts = NULL;
static size_t nconsts = 0, capconsts = 0;

static void const_add(const char* var, int line, const char* val, const char* type) {
    if (nconsts == capconsts) {
        capconsts = capconsts ? capconsts * 2 : 64;
        consts = (Constant*)realloc(consts, capconsts * sizeof(Constant));
    }
    consts[nconsts].var_name = xstrdup(var ? var : "-");
    consts[nconsts].line = line;
    consts[nconsts].value = xstrdup(val ? val : "");
    consts[nconsts].type = xstrdup(type ? type : "");
    nconsts++;
}

/* State tracking variables */
static int in_declaration = 0;
static char last_type[256] = {0};
static char last_ident[256] = {0};
static int last_was_ident = 0;
static int array_capture_for_ident = 0;
static int in_assignment = 0;
static char current_var[256] = {0};

static void start_declaration(const char* t) {
    in_declaration = 1;
    last_type[0] = '\0';
    if (t) {
        strncat(last_type, t, sizeof(last_type) - 1);
    }
}

static void add_type_token(const char* t) {
    if (last_type[0]) {
        strncat(last_type, " ", sizeof(last_type) - 1);
    }
    strncat(last_type, t, sizeof(last_type) - 1);
}

static void end_declaration() {
    in_declaration = 0;
    last_type[0] = '\0';
}

/* Function parameter tracking */
static int paren_depth = 0;
static int capturing_args = 0;
static char* arg_buffer = NULL;
static size_t arg_cap = 0, arg_len = 0;
static Symbol* current_func_sym = NULL;

static void args_begin(Symbol* s) {
    capturing_args = 1;
    paren_depth = 1;
    arg_len = 0;
    if (!arg_buffer) {
        arg_cap = 256;
        arg_buffer = (char*)malloc(arg_cap);
    }
    current_func_sym = s;
}

static void args_push_char(int c) {
    if (!capturing_args) return;
    if (arg_len + 2 > arg_cap) {
        arg_cap *= 2;
        arg_buffer = (char*)realloc(arg_buffer, arg_cap);
    }
    arg_buffer[arg_len++] = (char)c;
    arg_buffer[arg_len] = '\0';
}

static void args_end() {
    if (capturing_args && current_func_sym) {
        if (arg_len && arg_buffer[arg_len - 1] == ')') {
            arg_buffer[arg_len - 1] = '\0';
        }
        char* s = xstrdup(arg_buffer);
        trim(s);
        sym_append_params(current_func_sym, s);
        free(s);
    }
    capturing_args = 0;
    paren_depth = 0;
    arg_len = 0;
    current_func_sym = NULL;
}

/* Token printing and classification helpers */
static void print_token(const char* kind, const char* lexeme) {
    printf("[line %d] %-12s : %s\n", yylineno, kind, lexeme);
}

static const char* classify_int(const char* s) {
    if (!s) return "int";
    if (strlen(s) > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) return "hex";
    if (strlen(s) > 2 && s[0] == '0' && (s[1] == 'b' || s[1] == 'B')) return "bin";
    if (s[0] == '0' && strlen(s) > 1) return "oct";
    return "int";
}

static void print_symbol_table() {
    printf("\n==== SYMBOL TABLE ====\n");
    printf("%-20s %-15s %-12s %-10s %-15s %s\n", "Name", "Type", "Dimensions", "Frequency", "Return Type", "Parameters Lists in Function call");
    for (int i = 0; i < SYM_HASH_SIZE; i++) {
        for (Symbol* s = symtab[i]; s; s = s->next) {
            printf("%-20s %-15s %-12s %-10d %-15s %s\n",
                   s->name,
                   s->type ? s->type : "-",
                   s->dimensions ? s->dimensions : "-",
                   s->frequency,
                   s->return_type ? s->return_type : (s->is_function ? "unknown" : "-"),
                   s->param_lists ? s->param_lists : "-"
                  );
        }
    }
}

static void print_constant_table() {
    printf("\n==== CONSTANT TABLE ====\n");
    printf("%-20s %-10s %-30s %s\n", "Variable Name", "Line No.", "Value", "Type");
    for (size_t i = 0; i < nconsts; i++) {
        printf("%-20s %-10d %-30s %s\n",
               consts[i].var_name ? consts[i].var_name : "-",
               consts[i].line,
               consts[i].value ? consts[i].value : "",
               consts[i].type ? consts[i].type : ""
              );
    }
}
%}

%option noyywrap
%option yylineno

/* --------------- Definitions ------------------ */
%x COMMENT
%x STRING
%x CHARLIT
%x PP
%x FUNCARGS

DIGIT       [0-9]
LETTER      [A-Za-z_]
ID          {LETTER}[A-Za-z0-9_]*
WS          [ \t\r]+

HEX         0[xX][0-9A-Fa-f]+
BIN         0[bB][01]+
OCT         0[0-7]+
INTSUFFIX   ([uU][lL]?|[lL][uU]?|[uU][lL][lL]|[lL][lL][uU]?)
EXP         ([eE][+-]?{DIGIT}+)
FLOAT1      {DIGIT}+"."{DIGIT}+({EXP})?
FLOAT2      {DIGIT}+"."({EXP})?
FLOAT3      "."{DIGIT}+({EXP})?
FLOAT4      {DIGIT}+{EXP}
FLOATSUF    [fFlL]?

ESC         (\\[abfnrtv\\'"?]|\\x[0-9A-Fa-f]+|\\[0-7]{1,3})

%%

{WS}        { /* ignore */ }
\n          { /* ignore */ }

"//".*     { /* ignore single-line comments */ }

"/*"        {
    BEGIN(COMMENT);
    int depth = 1;
    int c1, c2;
    while (depth > 0) {
        c1 = input();
        if (c1 == EOF) {
            fprintf(stderr, "[line %d] ERROR: Unterminated comment\n", yylineno);
            BEGIN(INITIAL);
            break;
        }
        if (c1 == '\n') {
            /* Count newlines in comments */
        }
        if (c1 == '/') {
            c2 = input();
            if (c2 == '*') {
                depth++;
            } else if (c2 != EOF) {
                unput(c2);
            }
        } else if (c1 == '*') {
            c2 = input();
            if (c2 == '/') {
                depth--;
            } else if (c2 != EOF) {
                unput(c2);
            }
        }
    }
    BEGIN(INITIAL);
}

^[ \t]*\#[^\n\\]*(\\\n[^\n\\]*)* {
    print_token("PREPROC", yytext);
    char* tmp = xstrdup(yytext);
    char* p = tmp;

    while (*p == ' ' || *p == '\t') p++;
    if (*p == '#') p++;
    while (*p == ' ') p++;

    if (strncmp(p, "define", 6) == 0 && isspace((unsigned char)p[6])) {
        p += 6;
        while (*p == ' ') p++;

        char namebuf[256] = {0};
        int i = 0;
        while (*p && (isalnum((unsigned char)*p) || *p == '_')) {
            if (i < 255) namebuf[i++] = *p;
            p++;
        }
        namebuf[i] = '\0';
        while (*p == ' ' || *p == '\t') p++;

        char* val = trim(p);
        if (val && namebuf[0]) {
            const_add(namebuf, yylineno, val, "macro");
        }
    }
    free(tmp);
}

"auto"|"break"|"case"|"const"|"continue"|"default"|"do"|"else"|"enum"|"extern"|"for"|"goto"|"if"|"register"|"return"|"sizeof"|"static"|"struct"|"switch"|"typedef"|"union"|"volatile"|"while"|"inline"|"restrict"|"_Alignas"|"_Alignof"|"_Atomic"|"_Bool"|"_Complex"|"_Generic"|"_Imaginary"|"_Noreturn"|"_Static_assert"|"_Thread_local" {
    print_token("KEYWORD", yytext);
    last_was_ident = 0;
}

"void"|"char"|"short"|"int"|"long"|"float"|"double"|"signed"|"unsigned" {
    print_token("TYPE", yytext);
    if (!in_declaration) {
        start_declaration(yytext);
    } else {
        add_type_token(yytext);
    }
    last_was_ident = 0;
}

\"          {
    BEGIN(STRING);
    yyless(0);
}
<STRING>\"([^"\\\n]|{ESC})*\" {
    print_token("STRING", yytext);
    const_add(in_assignment ? current_var : "-", yylineno, yytext, "string");
    in_assignment = 0;
    BEGIN(INITIAL);
}
<STRING>\"([^"\\\n]|{ESC})*\\\n {
    /* continued line inside string - treat as part of string */
}
<STRING>\n  {
    fprintf(stderr, "[line %d] ERROR: Unterminated string literal\n", yylineno - 1);
    BEGIN(INITIAL);
}
<STRING>.   { /* consume */ }

\'          {
    BEGIN(CHARLIT);
    yyless(0);
}
<CHARLIT>\'([^'\\\n]|{ESC})+\' {
    print_token("CHAR", yytext);
    const_add(in_assignment ? current_var : "-", yylineno, yytext, "char");
    in_assignment = 0;
    BEGIN(INITIAL);
}
<CHARLIT>\n {
    fprintf(stderr, "[line %d] ERROR: Unterminated char literal\n", yylineno - 1);
    BEGIN(INITIAL);
}
<CHARLIT>.  { /* consume */ }

{DIGIT}+([.][0-9]+)+([.][0-9]+)*   {
    fprintf(stderr, "[line %d] ERROR: Invalid float literal '%s'\n", yylineno, yytext);
    last_was_ident = 0;
}

{DIGIT}+{LETTER}+([A-Za-z0-9_.])*   {
    fprintf(stderr, "[line %d] ERROR: Invalid number '%s'\n", yylineno, yytext);
    last_was_ident = 0;
}

{FLOAT1}{FLOATSUF}?/[^.0-9A-Za-z_]   { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "float"); in_assignment = 0; last_was_ident = 0; }
{FLOAT2}{FLOATSUF}?/[^.0-9A-Za-z_]   { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "float"); in_assignment = 0; last_was_ident = 0; }
{FLOAT3}{FLOATSUF}?/[^.0-9A-Za-z_]   { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "float"); in_assignment = 0; last_was_ident = 0; }
{FLOAT4}{FLOATSUF}?/[^.0-9A-Za-z_]   { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "float"); in_assignment = 0; last_was_ident = 0; }
{HEX}{INTSUFFIX}?/[^.0-9A-Za-z_]     { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "hex");   in_assignment = 0; last_was_ident = 0; }
{BIN}{INTSUFFIX}?/[^.0-9A-Za-z_]     { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "bin");   in_assignment = 0; last_was_ident = 0; }
{OCT}{INTSUFFIX}?/[^.0-9A-Za-z_]     { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, "oct");   in_assignment = 0; last_was_ident = 0; }
{DIGIT}+{INTSUFFIX}?/[^.0-9A-Za-z_]  { print_token("NUMBER", yytext); const_add(in_assignment ? current_var : "-", yylineno, yytext, classify_int(yytext)); in_assignment = 0; last_was_ident = 0; }

{ID}        {
    print_token("IDENT", yytext);
    Symbol* s = sym_touch(yytext);
    strncpy(last_ident, yytext, sizeof(last_ident) - 1);
    last_ident[sizeof(last_ident) - 1] = '\0';
    last_was_ident = 1;
    array_capture_for_ident = 1;
    if (in_declaration) {
        if (!s->type) {
            sym_set_type(s, last_type);
        }
    }
}

"("         {
    print_token("PUNCT", yytext);
    if (last_was_ident) {
        Symbol* s = sym_lookup(last_ident);
        if (!s) {
            s = sym_touch(last_ident);
        }
        if (in_declaration) {
            s->is_function = 1;
            if (last_type[0]) {
                sym_set_return(s, last_type);
            }
        }
        args_begin(s);
        BEGIN(FUNCARGS);
    }
    last_was_ident = 0;
}
<FUNCARGS>[^()\n]+ {
    /* collect raw text inside args */
    for (size_t i = 0; i < yyleng; i++) {
        args_push_char(yytext[i]);
    }
}
<FUNCARGS>"("      { args_push_char('('); paren_depth++; }
<FUNCARGS>")"      {
    args_push_char(')');
    paren_depth--;
    if (paren_depth == 0) {
        args_end();
        BEGIN(INITIAL);
    }
}
<FUNCARGS>\n       { args_push_char('\n'); }

")"         { print_token("PUNCT", yytext); last_was_ident = 0; }

"["{WS}*{DIGIT}+{WS}*"]" {
    print_token("PUNCT", yytext);
    if (array_capture_for_ident) {
        Symbol* s = sym_lookup(last_ident);
        if (s) {
            sym_append_dims(s, yytext);
        }
    }
    last_was_ident = 0;
}
"["|"]"     { print_token("PUNCT", yytext); last_was_ident = 0; }

";"         {
    print_token("PUNCT", yytext);
    array_capture_for_ident = 0;
    in_assignment = 0;
    if (in_declaration) {
        end_declaration();
    }
    last_was_ident = 0;
}
","         { print_token("PUNCT", yytext); last_was_ident = 0; }
"{"         {
    print_token("PUNCT", yytext);
    if (in_declaration) {
        end_declaration();
    }
    last_was_ident = 0;
}
"}"         { print_token("PUNCT", yytext); last_was_ident = 0; }

"."|"->"    { print_token("OP", yytext); last_was_ident = 0; }
"++"|"--"   { print_token("OP", yytext); last_was_ident = 0; }
"+="|"-="|"*="|"/="|"%=" { print_token("OP", yytext); last_was_ident = 0; }
"&="|"^="|"|="          { print_token("OP", yytext); last_was_ident = 0; }
"=="|"!="|"<="|">="     { print_token("OP", yytext); last_was_ident = 0; }
"<<"|">>"   { print_token("OP", yytext); last_was_ident = 0; }
"&&"|"||"   { print_token("OP", yytext); last_was_ident = 0; }
"+"|"-"|"*"|"/"|"%"     { print_token("OP", yytext); last_was_ident = 0; }
"<"|">"     { print_token("OP", yytext); last_was_ident = 0; }
"="         { 
    print_token("OP", yytext); 
    if (last_was_ident) {
        in_assignment = 1;
        strncpy(current_var, last_ident, sizeof(current_var) - 1);
        current_var[sizeof(current_var) - 1] = '\0';
    }
    last_was_ident = 0; 
}
"!"|"~"|"&"|"^"         { print_token("OP", yytext); last_was_ident = 0; }
"|"         { print_token("OP", yytext); last_was_ident = 0; }
"?"|":"     { print_token("OP", yytext); last_was_ident = 0; }

.           {
    fprintf(stderr, "[line %d] ERROR: Invalid token '%s'\n", yylineno, yytext);
}

%%

int main(int argc, char **argv) {
    if (argc > 1) {
        FILE* f = fopen(argv[1], "r");
        if (!f) {
            perror("fopen");
            return 1;
        }
        yyin = f;
    }
    yylex();
    print_symbol_table();
    print_constant_table();
    return 0;
}
