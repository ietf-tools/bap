#include <stdio.h>
#include "common.h"

struct rule *rules = NULL;

main()
{
	struct rule *r;
#ifdef YYDEBUG
	extern int yydebug;

	yydebug = 0;
#endif
	yyparse();
	for (r = rules; r; r = r->next) {
		printf("%s <line %d> = ", r->name, r->line);
		printobj(r->rule);
		printf("\n");
	}
}

void
printrep(struct range *rep)
{
	if (rep->lo == 1 && rep->hi == 1)
		return;
	if (rep->lo > 0)
		printf("%d", rep->lo);
	if (rep->lo == rep->hi)
		return;
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
				char *p = o->u.e.e.termstr.str;
				char sep;
				printf("%%");
				sep = 'x';
				while (*p) {
					printf("%c%x", sep, *p++);
					sep = '.';
				}
			} else {
				printf("%c%s%c", '"', o->u.e.e.termstr.str, '"');
			}
			break;
		case T_TERMRANGE:
			printrep(&o->u.e.repetition);
			printf("%%x%x-%x", o->u.e.e.termrange.lo,
				o->u.e.e.termrange.hi);
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
