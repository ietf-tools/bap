#include <stdio.h>
#include <search.h>
#include "common.h"

#define	MAXRULE		1000	/* XXX */

struct rule *rules = NULL;

main()
{
	struct rule *r;
#ifdef YYDEBUG
	extern int yydebug;

	yydebug = 0;
#endif
	hcreate(MAXRULE);

	yyparse();
	for (r = rules; r; r = r->next) {
		if (r->rule) {
			printf("%s = ", r->name);
			printobj(r->rule);
			printf(" ; line %d\n", r->line);
		} else {
			printf("; %s = <UNDEFINED>\n", r->name);
		}
		if (r->next == rules)
			break;
	}
	hdestroy();
}

void
printrep(struct range *rep)
{
	if (rep->lo == 1 && rep->hi == 1)
		return;
	if (rep->lo > 0)
		printf("%d", rep->lo);
	if (rep->lo == rep->hi) {
		if (rep->lo == 0)
			printf("0");
		return;
	}
	printf("*");
	if (rep->hi > 0)
		printf("%d", rep->hi);
}

void
printobj(object *o)
{
	printobj_r(o, 0);
}

static void
printobj_r(object *o, int parenttype)
{
	int iterating = 0;

	if (parenttype != T_GROUP && o->next) {
		iterating = 1;
		printf("( ");
	}
	while (o) {
/*		printf("<%d>", o->type);*/
		switch (o->type) {
		case T_ALTERNATION:
			if (o->next)
				printf("( ");
			printobj_r(o->u.alternation.left, o->type);
			printf(" / ");
			printobj_r(o->u.alternation.right, o->type);
			if (o->next)
				printf(" )");
			break;
		case T_RULE:
			printrep(&o->u.e.repetition);
			printf("%s", o->u.e.e.rule.name);
			break;
		case T_GROUP:
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				printf("[ ");
			} else {
				printrep(&o->u.e.repetition);
				printf("( ");
			}
			printobj_r(o->u.e.e.group, o->type);
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				printf(" ]");
			} else {
				printf(" )");
			}
			break;
		case T_TERMSTR:
			printrep(&o->u.e.repetition);
			if (o->u.e.e.termstr.flags & F_CASESENSITIVE) {
				unsigned char *p = o->u.e.e.termstr.str;
				char sep;
				printf("%%");
				sep = 'x';
				while (*p) {
					printf("%c%02X", sep, *p++);
					sep = '.';
				}
			} else {
				printf("%c%s%c", '"', o->u.e.e.termstr.str, '"');
			}
			break;
		case T_TERMRANGE:
			printrep(&o->u.e.repetition);
			printf("%%x%02X-%02X",
				(unsigned char)o->u.e.e.termrange.lo,
				(unsigned char)o->u.e.e.termrange.hi);
			break;
		case T_PROSE:
			printf("<%s>", o->u.proseval);
			break;
		}
		if (o->next)
			printf(" ");
		o = o->next;
	}
	if (iterating)
		printf(" )");
}

struct rule *
findrule(char *name)
{
	char *lowername;
	char *p, *q;
	ENTRY *e;
	ENTRY search;
	struct rule *r;

	lowername = malloc(strlen(name) + 1);
	for (p = name, q = lowername; *p; p++, q++)
		if (isupper(*p))
			*q = tolower(*p);
		else
			*q = *p;
	*q = '\0';
	search.key = lowername;
	search.data = NULL;
	e = hsearch(search, FIND);
	if (e == NULL) {
		r = calloc(1, sizeof(struct rule));
		r->name = name;
		r->lowername = lowername;
		search.data = r;
		e = hsearch(search, ENTER);
		if (e == NULL) {
			fprintf(stderr, "hash table full -- increase MAXRULE\n");
			exit(1);
		}
		if (rules) {
			r->next = rules;
			r->prev = rules->prev;
			rules->prev->next = r;
			rules->prev = r;
		} else {
			rules = r->next = r->prev = r;
		}
		return r;
	} else {
		free(lowername);
		return (struct rule *)e->data;
	}
}
