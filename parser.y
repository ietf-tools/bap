%{
/*
 * Bill's ABNF parser.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "common.h"

static const char rcsid[] =
 "$Fenner: abnf-parser/parser.y,v 1.13 2002/07/30 17:05:00 fenner Exp $";

extern int yylineno, yycolumn;

int defline;
extern struct rule *rules;

#ifdef YYERROR_VERBOSE
/* HACK-O-ROONIE for yyerror verbosity */
int *yystatep = NULL;
int *yychar1p = NULL;
#endif

int pipewarn = 0;

object *newobj(int);
%}

%union {
	char *string;
	struct range range;
	object *object;
	int retval;
}

%token <string> CHARVAL PROSEVAL BINVAL DECVAL HEXVAL RULENAME
%token <range> BINVALRANGE DECVALRANGE HEXVALRANGE REPEAT
%token CWSP EQSLASH CRLF

%type <string> numval
%type <range> numvalrange
%type <object> element group option repetition elements
%type <object> rulerest
%type <retval> definedas

%%

begin:	{
#ifdef YYERROR_VERBOSE
	/* HACK-O-RAMA */ yystatep = &yystate; yychar1p = &yychar1;
#endif
		} rulelist
	;

rulelist: rules
	| rulelist rules
	;

rules:	  rule
	| starcwsp CRLF
	| cwsp RULENAME	{ mywarn("Indented rules are Right Out."); YYERROR; }
	;

recover:
	| error CRLF
	;

rule:	recover RULENAME { defline = yylineno; } definedas rulerest {
		struct rule *r;

		r = findrule($2);

		if ($4 == 0 || r->name == NULL || r->rule == NULL) {	/* = */
			if ($4) {
				mywarn("Rule %s does not yet exist; treating /= as =", $2);
			}
			if (r->name && strcmp(r->name, $2))
				mywarn("Rule %s previously %s as %s", $2,
					r->rule ? "defined" : "referred to", r->name);
			if (r->rule)
				mywarn("Rule %s was already defined on line %d", $2,
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
		} else {	/* =/ */
			object *tmp;

			tmp = newobj(T_ALTERNATION);
			tmp->u.alternation.left = r->rule;
			tmp->u.alternation.right = $5;
			r->rule = tmp;
		}
		}
	;

definedas: starcwsp EQSLASH starcwsp	{ $$ = 1; }
	| starcwsp '=' starcwsp		{ $$ = 0; }
	| starcwsp '=' starcwsp CRLF { mywarn("Empty rule"); YYERROR; /* XXX this CRLF may be the one required to recover from the error, but we've already used it... */}
	| starcwsp repetition { mywarn("Got definitions, expecting '=' or '=/'"); YYERROR; }
	| starcwsp CRLF { mywarn("Got EOL, expecting '=' or '=/'"); YYERROR; /* XXX this CRLF may be the one required to recover from the error, but we've already used it... */}
	;

cwsp:	  CWSP
	;

starcwsp:
	| CWSP
	;

rulerest: elements starcwsp CRLF	{ $$ = $1; }
	| elements ')'	{ mywarn("Extra ')'?  Missing '('?"); YYERROR; }
	| elements ']'	{ mywarn("Extra ']'?  Missing '['?"); YYERROR; }
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
		if (!pipewarn) {
			mywarn("'/' is the alternation character in ABNF");
			pipewarn = 1;
		}
		$$ = newobj(T_ALTERNATION);
		$$->u.alternation.left = $1;
		$$->u.alternation.right = $5;
		}
	| elements repetition {
		object *o = $1;
		mywarn("Concatenation of adjacent elements (missing whitespace?)");
		printf("; line %d ... trying to concatenate ", yylineno);
		if (o->type == T_ALTERNATION)
			o = o->u.alternation.right;
		while (o->next)	/* n**2, do this better */
			o = o->next;
		printobj(o, 1);
		printf("\n; ... with ");
		printobj($2, 1);
		printf("\n");
		YYERROR;
		}
	| elements starcwsp '=' {
		mywarn("Encountered definition while parsing rule (Indented rule?)");
		YYERROR;
		}
	| elements starcwsp EQSLASH {
		mywarn("Encountered definition while parsing rule (Indented rule?)");
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
					mywarn("Repeat range swapped, should be min*max");
				if ($1.hi == 0)
					mywarn("Absolute repeat count of zero means this element may not occur at all");
				}
	| REPEAT cwsp		{
				mywarn("No whitespace allowed between repeat and element.");
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
					mywarn("Rule %s referred to as %s", $$->u.e.e.rule.rule->name, $1);
				}
	| group	
	| option
	| CHARVAL		{
				char *p = $1;
				if (*$1)
					p += strlen($1) - 1;
				if (*p == '\n' || *p == '\r') {
					mywarn("unterminated quoted-string");
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
				$$->u.e.e.proseval = $1;
				}
	;

group:	  '(' starcwsp elements starcwsp ')'	{
						$$ = newobj(T_GROUP);
						$$->u.e.e.group = $3;
						}
	| '(' starcwsp elements starcwsp CRLF {
		mywarn("Missing ')'?  Extra '('?");
		YYERROR;
		}
	;

option:	  '[' starcwsp elements starcwsp ']'	{
						$$ = newobj(T_GROUP);
						$$->u.e.e.group = $3;
						$$->u.e.repetition.lo = 0;
						}
	| '[' starcwsp elements starcwsp CRLF {
		mywarn("Missing ']'?  Extra '['?");
		YYERROR;
		}
	;

%%

void
mywarn(const char *fmt, ...)
{
	va_list ap;

	/* file name */
	fprintf(stderr, "%d:%d: ", yylineno, yycolumn);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
}

int
yyerror(char *s)
{
#ifdef YYERROR_VERBOSE
	mywarn("state %d, token %s: %s", 
		*yystatep,
		(yychar1p && (*yychar1p >= 0 && *yychar1p <= (sizeof(yytname)/sizeof(yytname[0])))) ? yytname[*yychar1p] : "?",
		s);
#else
	mywarn("%s\n", s);
#endif
}

object *
newobj(int type)
{
	object *o;

	o = calloc(sizeof(object), 1);
	if (o == NULL) {
		mywarn("out of memory");
		exit(1);
	}
	o->type = type;
	o->next = NULL;
	switch (type) {
		case T_RULE:
		case T_GROUP:
		case T_TERMSTR:
		case T_TERMRANGE:
		case T_PROSE:
			o->u.e.repetition.lo = 1;
			o->u.e.repetition.hi = 1;
			break;
	}
	return o;
}
