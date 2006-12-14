/*
 * Bill's ABNF Parser
 * Copyright 2002-2006 William C. Fenner <fenner@fenron.com>
 *  All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the author nor the names of contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY WILLIAM C. FENNER ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WILLIAM C. FENNER OR HIS
 * BROTHER B1FF BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */

#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <search.h>
#include <unistd.h>
#include "common.h"

static const char rcsid[] =
 "$Fenner: abnf-parser/main.c,v 1.23 2006/12/07 22:45:10 fenner Exp $";
static const char versionstring[] = "1.1";

static void printobj_r(object *, int, int);
static void canonify(struct rule *);
static void canonify_r(struct object **);

#define	MAXRULE		1000	/* XXX */

struct rule *rules = NULL;

int cflag = 0;		/* include line number comments */
int c2flag = 0;		/* include comments for printable constants */
int tflag = 0;		/* print type info */
int permissive = 1;	/* Be permissive (e.g. accept '|') */
int qflag = 0;		/* quiet */
int canon = 1;		/* canonify */

void
usage(void)
{
	fprintf(stderr, "Bill's ABNF Parser version %s\n", versionstring);
	fprintf(stderr, "usage: bap [-ckntq]\n");
	fprintf(stderr, " -c : include rule definition line # in comment\n");
	fprintf(stderr, " -k : add comments for printable characters specified as %%x\n");
	fprintf(stderr, " -n : don't \"canonify\" result\n");
	fprintf(stderr, " -t : include type info in result\n");
	fprintf(stderr, " -q : don't print parsed grammar\n");
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

	while ((ch = getopt(argc, argv, "cdkntq")) != -1) {
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

		case 'k':
			c2flag++;
			break;

		case 'n':
			canon = 0;
			break;

		case 't':
			tflag++;
			break;

		case 'p':
			permissive = 0;
			break;

		case 'q':
			qflag++;
			break;

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc > 0)
		usage();

	/* Parse the grammar, perhaps spouting errors. */
	yyparse();
	/* If we're not quiet, then output the grammar again. */
	if (!qflag) {
		if (canon)
			canonify(rules);
		for (r = rules; r; r = r->next) {
			if (r->rule) {
				printf("%s = ", r->name);
				printobj(r->rule, tflag);
				if (cflag)
					printf(" ; line %d", r->line);
				printf("\n");
			} else {
				printf("; %s UNDEFINED\n", r->name);
			}
			if (r->next == rules)
				break;
		}
		for (r = rules; r; r = r->next) {
			if (r->used == 0 && r->rule)
				printf("; %s defined but not used\n", r->name);
			if (r->next == rules)
				break;
		}
	}
	hdestroy();
	exit(0);
}

void
canonify(struct rule *rules)
{
	struct rule *r;

	for (r = rules; r; r = r->next) {
		if (r->rule)
			canonify_r(&r->rule);
		if (r->next == rules)
			break;
	}
}

/* XXX may need to modify in the future? */
void
canonify_r(struct object **op)
{
	struct object *o = *op;
	while (o) {
		switch (o->type) {
		case T_ALTERNATION:
			canonify_r(&o->u.alternation.left);
			canonify_r(&o->u.alternation.right);
			break;
		case T_RULE:
			/* nothing to do */
			break;
		case T_GROUP:
			canonify_r(&o->u.e.e.group);
			break;
		case T_TERMSTR:
			while (o->next && o->next->type == T_TERMSTR &&
			    o->u.e.repetition.lo == 1 && o->u.e.repetition.hi == 1 &&
			    o->next->u.e.repetition.lo == 1 && o->next->u.e.repetition.hi == 1 &&
			    ((o->u.e.e.termstr.flags & F_CASESENSITIVE) ==
			     (o->next->u.e.e.termstr.flags & F_CASESENSITIVE))) {
				int len = strlen(o->u.e.e.termstr.str) + strlen(o->next->u.e.e.termstr.str);
				char *p = malloc(len + 1);
				strcpy(p, o->u.e.e.termstr.str);
				strcat(p, o->next->u.e.e.termstr.str);
				free(o->u.e.e.termstr.str);
				o->u.e.e.termstr.str = p;
				/* XXX leak o->next */
				o->next = o->next->next;
			}
			if (o->u.e.e.termstr.flags & F_CASESENSITIVE) {
				int anybad = 0;
				char *p;
				for (p = o->u.e.e.termstr.str; *p; p++) {
					if (isalpha(*p) || *p == '"' || !isprint(*p)) {
						anybad = 1;
						break;
					}
				}
				if (anybad == 0)
					o->u.e.e.termstr.flags &= ~F_CASESENSITIVE;
			}
		case T_TERMRANGE:
		case T_PROSE:
		default:
			/* nothing to do */
			break;
		}
		o = o->next;
	}
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
	if (rep->hi != -1)
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

/*
 * No brackets needed around a group that
 * contains a single element that has a
 * possible repetition of 0.
 */
#define NOBRACKET(o)	((o->next == NULL) && (o->u.e.repetition.lo == 0))

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
			if (o->u.e.e.rule.rule) {
				printf("%s", o->u.e.e.rule.rule->name);
				o->u.e.e.rule.rule->used = 1;
			} else
				printf("%s", o->u.e.e.rule.name);
			break;
		case T_GROUP:
			if (tflag)
				printf("{GROUP}");
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				if (!NOBRACKET(o->u.e.e.group))
					printf("[ ");
			} else {
				printrep(&o->u.e.repetition);
				if (!NOPAREN(o->u.e.e.group))
					printf("( ");
			}
			printobj_r(o->u.e.e.group, o->type, tflag);
			if (o->u.e.repetition.lo == 0 &&
			    o->u.e.repetition.hi == 1) {
				if (!NOBRACKET(o->u.e.e.group))
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
				int allprintable = 1;
				printf("%%");
				sep = 'x';
				while (*p) {
					if (!isgraph(*p)) allprintable = 0;
					printf("%c%02X", sep, *p++);
					sep = '.';
				}
				if (c2flag && allprintable)
					printf(" ; %s\n", o->u.e.e.termstr.str);
			} else {
				printf("%c%s%c", '"', o->u.e.e.termstr.str, '"');
			}
			break;
		case T_TERMRANGE:
			if (tflag)
				printf("{TERMRANGE}");
			printrep(&o->u.e.repetition);
			printf("%%x%02X-%02X",
				o->u.e.e.termrange.lo,
				o->u.e.e.termrange.hi);
			/* XXX isprint does not handle non-ASCII */
			if (c2flag &&
			    isprint(o->u.e.e.termrange.lo) &&
			    isprint(o->u.e.e.termrange.hi)) {
				printf(" ; '%c'-'%c'\n",
					o->u.e.e.termrange.lo,
					o->u.e.e.termrange.hi);
			}
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
