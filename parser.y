%{
/*
 * Bill's ABNF parser.
 */

#include <stdio.h>
#include <stdlib.h>

#include "common.h"

extern int yylineno, yycolumn;

int defline;
extern struct rule *rules;

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
		r = findrule($2);
		if (r->name && strcmp(r->name, $2))
			yyerror("Rule %s previously %s as %s", $2,
				r->rule ? "defined" : "referred to", r->name);
		if (r->rule)
			yyerror("Rule %s was already defined on line %d",
				r->line);
		else {
			r->name = $2;
			r->line = defline;
			r->rule = $5;
			if (r->next != rules) {
				/* unlink r from where it is and move to the end */
				r->prev->next = r->next;
				r->next->prev = r->prev;
				if (rules == r)
					rules = r->next;
				r->prev = rules->prev;
				rules->prev = r;
				r->prev->next = r;
				r->next = rules;
			}
		}
		}
	;

definedas: starcwsp EQSLASH starcwsp
	| starcwsp '=' starcwsp
	| starcwsp '=' starcwsp CRLF { yyerror("Empty rule"); YYERROR; }
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
		object *o = $1;
		yyerror("Concatenation of adjacent elements!?");
		printf("; ... trying to concatenate ");
		if (o->type == T_ALTERNATION)
			o = o->u.alternation.right;
		while (o->next)	/* n**2, do this better */
			o = o->next;
		printobj(o);
		printf(" with ");
		printobj($2);
		printf("\n");
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
				if ($1.hi < $1.lo && $1.hi != -1)
					yyerror("Repeat range swapped, should be min*max");
				if ($1.hi == 0)
					yyerror("Absolute repeat count of zero means this element may not occur at all");
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
				$$->u.e.e.rule.rule = findrule($1);
				if (strcmp($1, $$->u.e.e.rule.rule->name))
					yyerror("Rule %s referred to as %s", $$->u.e.e.rule.rule->name, $1);
				}
	| group	
	| option
	| CHARVAL		{
				char *p = $1;
				if (*$1)
					p += strlen($1) - 1;
				if (*p == '\n' || *p == '\r') {
					yyerror("unterminated quoted-string");
					YYERROR;
				}
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
	fprintf(stderr, "yyerror: line %d:%d: state %d, token %s: %s\n", yylineno, yycolumn,
		yystatep ? *yystatep : -2468,
		(yychar1p && (*yychar1p >= 0 && *yychar1p <= (sizeof(yytname)/sizeof(yytname[0])))) ? yytname[*yychar1p] : "?",
		s);
#else
	fprintf(stderr, "yyerror: line %d:%d: %s\n", yylineno, yycolumn, s);
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
