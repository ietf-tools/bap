%{
/*
 * Bill's ABNF parser.
 */

#include <stdio.h>
#include <stdlib.h>

#include "common.h"

extern int yylineno;

int defline;
extern struct rule *rules;
struct rule *lastrule = NULL;

/* HACK-O-ROONIE for yyerror verbosity */
int *yystatep = NULL;
int *yychar1p = NULL;

object *newobj(int);
%}

%union {
	char *string;
	struct range range;
	object *object;
}

%token <string> CHARVAL PROSEVAL BINVAL DECVAL HEXVAL RULENAME
%token <range> BINVALRANGE DECVALRANGE HEXVALRANGE REPEAT
%token CWSP EQSLASH CRLF

%type <string> numval
%type <range> numvalrange
%type <object> element group option repetition elements
%type <object> rulerest

%%

begin:	{ /* HACK-O-RAMA */ yystatep = &yystate; yychar1p = &yychar1; } rulelist
	;

rulelist: rules
	| rulelist rules
	;

rules:	  rule
	| starcwsp CRLF
	| cwsp RULENAME	{ yyerror("Indented rules are Right Out."); YYERROR; }
	;

recover:
	| error CRLF
	;

rule:	recover RULENAME { defline = yylineno } definedas rulerest {
		struct rule *r;
		r = calloc(sizeof(struct rule), 1);
		r->name = $2;
		r->line = defline;
		r->rule = $5;
		r->next = NULL;
		if (lastrule == NULL)
			rules = r;
		else
			lastrule->next = r;
		lastrule = r;
		printf("Rule %s defined on line %d\n", $2, defline);
		}
	;

definedas: starcwsp EQSLASH starcwsp
	| starcwsp '=' starcwsp
	| starcwsp repetition { yyerror("Got definitions, expecting '=' or '=/'"); YYERROR; }
	| starcwsp CRLF { yyerror("Got EOL, expecting '=' or '=/'"); YYERROR; }
	;

cwsp:	  CWSP
	;

starcwsp:
	| CWSP
	;

rulerest: elements starcwsp CRLF	{ $$ = $1; }
	| elements ')'	{ yyerror("Extra ')'?  Missing '('?"); YYERROR; }
	| elements ']'	{ yyerror("Extra ']'?  Missing '['?"); YYERROR; }
	;

elements:
	  repetition
	| elements cwsp repetition			{
		/* concatenation */
		object *o = $1;

		$$ = $1;
		if (o->type == T_ALTERNATION)
			o = o->u.alternation.right;
		while (o->next)	/* n**2, do this better */
			o = o->next;
		o->next = $3;
		}
	| elements starcwsp '/' starcwsp repetition	{
		$$ = newobj(T_ALTERNATION);
		$$->u.alternation.left = $1;
		$$->u.alternation.right = $5;
		}
	| elements starcwsp '|' starcwsp repetition	{
		$$ = newobj(T_ALTERNATION);
		$$->u.alternation.left = $1;
		$$->u.alternation.right = $5;
		}
	| elements repetition {
		yyerror("Concatenation of adjacent elements!?");
		YYERROR;
		}
	| elements starcwsp '=' {
		yyerror("Encountered definition while parsing rule (Indented rule?)");
		YYERROR;
		}
	| elements starcwsp EQSLASH {
		yyerror("Encountered definition while parsing rule (Indented rule?)");
		YYERROR;
		}
	;

repetition:
	  element
	| REPEAT element	{
				$$ = $2;
				/* 5*10[foo] is really *10(foo), so leave
				 * the zero that [ put there. */
				if ($$->u.e.repetition.lo != 0)
					$$->u.e.repetition.lo = $1.lo;
				$$->u.e.repetition.hi = $1.hi;
				}
	| REPEAT cwsp		{
				yyerror("No whitespace allowed between repeat and element.");
				YYERROR;
				}
	;

numval:   BINVAL
	| DECVAL
	| HEXVAL
	;

numvalrange:
	  BINVALRANGE
	| DECVALRANGE
	| HEXVALRANGE
	;

element:
	  RULENAME		{
				$$ = newobj(T_RULE);
				$$->u.e.e.rule.name = $1;
				$$->u.e.e.rule.rule = NULL;	/* lookup */
				printf("element rule %s\n", $1);
				}
	| group	
	| option
	| CHARVAL		{
				$$ = newobj(T_TERMSTR);
				$$->u.e.e.termstr.str = $1;
				$$->u.e.e.termstr.flags = 0;
				}
	| numval		{
				$$ = newobj(T_TERMSTR);
				$$->u.e.e.termstr.str = $1;
				$$->u.e.e.termstr.flags = F_CASESENSITIVE;
				}
	| numvalrange		{
				$$ = newobj(T_TERMRANGE);
				$$->u.e.e.termrange.lo = $1.lo;
				$$->u.e.e.termrange.hi = $1.hi;
				}
	| PROSEVAL		{
				$$ = newobj(T_PROSE);
				$$->u.proseval = $1;
				}
	;

group:	  '(' starcwsp elements starcwsp ')'	{
						$$ = newobj(T_GROUP);
						$$->u.e.e.group = $3;
						}
	| '(' starcwsp elements starcwsp CRLF {
		yyerror("Missing ')'?  Extra '('?");
		YYERROR;
		}
	;

option:	  '[' starcwsp elements starcwsp ']'	{
						$$ = newobj(T_GROUP);
						$$->u.e.e.group = $3;
						$$->u.e.repetition.lo = 0;
						}
	| '[' starcwsp elements starcwsp CRLF {
		yyerror("Missing ']'?  Extra '['?");
		YYERROR;
		}
	;

%%

int
yyerror(char *s)
{
#ifdef YYERROR_VERBOSE
	fprintf(stderr, "yyerror: line %d: state %d, token %s: %s\n", yylineno,
		yystatep ? *yystatep : -2468,
		(yychar1p && (*yychar1p >= 0 && *yychar1p <= (sizeof(yytname)/sizeof(yytname[0])))) ? yytname[*yychar1p] : "?",
		s);
#else
	fprintf(stderr, "yyerror: line %d: %s\n", yylineno, s);
#endif
}

object *
newobj(int type)
{
	object *o;

	o = calloc(sizeof(object), 1);
	if (o == NULL) {
		yyerror("out of memory");
		exit(1);
	}
	o->type = type;
	o->next = NULL;
	switch (type) {
		case T_RULE:
		case T_GROUP:
		case T_TERMSTR:
		case T_TERMRANGE:
			o->u.e.repetition.lo = 1;
			o->u.e.repetition.hi = 1;
			break;
	}
	return o;
}
