#include <stdio.h>
#include <stdlib.h>
#include <search.h>
#include <unistd.h>
#include "common.h"

void printobj(object *, int);
static void printobj_r(object *, int, int);

#define	MAXRULE		1000	/* XXX */

struct rule *rules = NULL;

int cflag = 0;		/* suppress line number comments */
int tflag = 0;		/* print type info */
int permissive = 1;	/* Be permissive (e.g. accept '|') */

void
usage(void)
{
	fprintf(stderr, "usage: p [-d]\n");
	exit(1);
}

int
main(int argc, char **argv)
{
	int ch;
	struct rule *r;
#ifdef YYDEBUG
	extern int yydebug;

	yydebug = 0;
#endif
	hcreate(MAXRULE);

	while ((ch = getopt(argc, argv, "cdt")) != -1) {
		switch (ch) {
		case 'c':
			cflag++;
			break;

		case 'd':
#ifdef YYDEBUG
			yydebug = 1;
#else
			fprintf(stderr, "Rebuild with -DYYDEBUG to use -d.\n");
#endif
			break;

		case 't':
			tflag++;
			break;

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	yyparse();
	for (r = rules; r; r = r->next) {
		if (r->rule) {
			printf("%s = ", r->name);
			printobj(r->rule, tflag);
			if (!cflag)
				printf(" ; line %d", r->line);
			printf("\n");
		} else {
			printf("; %s = <UNDEFINED>\n", r->name);
		}
		if (r->next == rules)
			break;
	}
	hdestroy();
	exit(0);
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
printobj(object *o, int tflag)
{
	/* T_GROUP means don't put grouping characters
	 * around the top level. */
	printobj_r(o, T_GROUP, tflag);
}

/*
 * No paren needed around a group that's:
 * - not concatenation (no next)
 * - not an ALTERNATION
 * - got a repeat count of 1
 */
#define	NOPAREN(o)	((o->next == NULL) && (o->type != T_ALTERNATION) && (o->u.e.repetition.lo == 1 && o->u.e.repetition.hi == 1))

static void
printobj_r(object *o, int parenttype, int tflag)
{
	int iterating = 0;

	/* Put parenthesis around concatenations */
	if (parenttype != T_GROUP && o->next) {
		iterating = 1;
		printf("( ");
	}
	while (o) {
		switch (o->type) {
		case T_ALTERNATION:
			if (tflag)
				printf("{ALTERNATION}");
			if (o->next)
				printf("( ");
			printobj_r(o->u.alternation.left, o->type, tflag);
			printf(" / ");
			printobj_r(o->u.alternation.right, o->type, tflag);
			if (o->next)
				printf(" )");
			break;
		case T_RULE:
			if (tflag)
				printf("{RULE}");
			printrep(&o->u.e.repetition);
			printf("%s", o->u.e.e.rule.name);
			break;
		case T_GROUP:
			if (tflag)
				printf("{GROUP}");
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				printf("[ ");
			} else {
				printrep(&o->u.e.repetition);
				if (!NOPAREN(o->u.e.e.group))
					printf("( ");
			}
			printobj_r(o->u.e.e.group, o->type, tflag);
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				printf(" ]");
			} else {
				if (!NOPAREN(o->u.e.e.group))
					printf(" )");
			}
			break;
		case T_TERMSTR:
			if (tflag)
				printf("{TERMSTR}");
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
			if (tflag)
				printf("{TERMRANGE}");
			printrep(&o->u.e.repetition);
			printf("%%x%02X-%02X",
				(unsigned char)o->u.e.e.termrange.lo,
				(unsigned char)o->u.e.e.termrange.hi);
			break;
		case T_PROSE:
			if (tflag)
				printf("{PROSE}");
			printrep(&o->u.e.repetition);
			printf("<%s>", o->u.e.e.proseval);
			break;
		default:
			printf("{UNKNOWN OBJECT TYPE %d}", o->type);
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
