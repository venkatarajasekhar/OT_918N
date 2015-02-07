
#ifndef READER_H_
# define READER_H_

# include "location.h"
# include "symlist.h"

# include "parse-gram.h"

typedef struct merger_list
{
  struct merger_list* next;
  uniqstr name;
  uniqstr type;
} merger_list;

/* From the scanner.  */
extern FILE *gram_in;
extern int gram__flex_debug;
extern boundary scanner_cursor;
extern char *last_string;
extern location last_braced_code_loc;
extern int max_left_semantic_context;
void scanner_initialize (void);
void scanner_free (void);
void scanner_last_string_free (void);

extern FILE *gram_out;
extern int gram_lineno;

# define YY_DECL int gram_lex (YYSTYPE *val, location *loc)
YY_DECL;


/* From the parser.  */
extern int gram_debug;
int gram_parse (void);
char const *token_name (int type);


/* From reader.c. */
void grammar_start_symbol_set (symbol *sym, location loc);
void prologue_augment (const char *prologue, location loc);
void grammar_current_rule_begin (symbol *lhs, location loc);
void grammar_current_rule_end (location loc);
void grammar_midrule_action (void);
void grammar_current_rule_prec_set (symbol *precsym, location loc);
void grammar_current_rule_dprec_set (int dprec, location loc);
void grammar_current_rule_merge_set (uniqstr name, location loc);
void grammar_current_rule_symbol_append (symbol *sym, location loc);
void grammar_current_rule_action_append (const char *action, location loc);
extern symbol_list *current_rule;
void reader (void);
void free_merger_functions (void);

extern merger_list *merge_functions;

/* Was %union seen?  */
extern bool typed;

/* Should rules have a default precedence?  */
extern bool default_prec;

#endif /* !READER_H_ */