/*
 * Bill's ABNF Parser
 * Copyright 2002-2006 William C. Fenner <fenner@research.att.com>
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
#include <ctype.h>
#include <string.h>
#include "common.h"

static const char rcsid[] =
  "$Id$";
static const char versionstring[] = PACKAGE_VERSION;

static void printobj_r(object *, int, int);
static void canonify(struct rule *);
static void canonify_r(struct object **);
static void parse_from(char *filename);
static void predefine(fn_list *ifile);
static int summary(void);

#define	MAXRULE		1000	/* XXX */

struct rule *rules = NULL;
char *input_file; /* of current input file */

char *top_rule_name = "ABNF";

int cflag = 0;		/* include line number comments */
int c2flag = 0;		/* include comments for printable constants */
int tflag = 0;		/* print type info */
int permissive = 1;	/* Be permissive (e.g. accept '|') */
int qflag = 0;		/* quiet */
int canon = 1;		/* canonify */

int yyparse(void);

void
usage(void)
{
	fprintf(stderr, "Bill's ABNF Parser version %s\n", versionstring);
	fprintf(stderr, "usage: bap [-cikntq] [ file ]\n");
	fprintf(stderr, " parse ABNF grammar from file or stdin\n");
	fprintf(stderr, " -c      : include rule definition line # in comment\n");
	fprintf(stderr, " -k      : add comments for printable characters specified as %%x\n");
	fprintf(stderr, " -n      : don't \"canonify\" result\n");
	fprintf(stderr, " -i file : read predefined rules from \"file\"\n");
	fprintf(stderr, " -t      : include type info in result\n");
	fprintf(stderr, " -q      : don't print parsed grammar\n");
	fprintf(stderr, " -S name : name rule as production start\n");
	exit(1);
}

int
main(int argc, char **argv)
{
	int ch;
	int rc = 0;
	struct rule *r;
	fn_list *pre_input = NULL;
  
#ifdef YYDEBUG
	extern int yydebug;

	yydebug = 0;
#endif
	hcreate(MAXRULE);

	while ((ch = getopt(argc, argv, "cdi:kntqS:")) != -1) {
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

		case 'i': {
			fn_list *ifile = calloc(sizeof(fn_list), 1);
			ifile->filename = optarg;
			ifile->next = pre_input;
			pre_input = ifile;
			break;
		}
      
		case 't':
			tflag++;
			break;

		case 'p':
			permissive = 0;
			break;

		case 'q':
			qflag++;
			break;

		case 'S': 
			top_rule_name = optarg;
			break;
      
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc > 1)
		usage();

	predefine(pre_input);    
  
	/* Parse the grammar, perhaps spouting errors. */
	parse_from((argc > 0)? argv[0] : NULL);

	/* If we're not quiet, then output the grammar again. */
	if (!qflag) {
		if (canon)
			canonify(rules);
		for (r = rules; r; r = r->next) {
			if (r->predefined) {
				/* do not output */
			}
			else if (r->rule) {
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
			if (r->used == 0 
				&& r->predefined == 0 
				&& r->rule 
				&& strcmp(r->name, top_rule_name))
				printf("; %s defined but not used\n", r->name);
			if (r->next == rules)
				break;
		}
	}
  
	rc = summary();
	hdestroy();
	exit(rc);
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
			if (o->u.e.islist) {
        if (o->u.e.repetition.lo == 0) {
          printf("( [ *LWS ");
  			  if (o->u.e.e.rule.rule) {
  				  printf("%s", o->u.e.e.rule.rule->name);
  				  o->u.e.e.rule.rule->used = 1;
  			  }
          else {
  				  printf("%s", o->u.e.e.rule.name);
          }
          printf(" ] *( *LWS \",\" *LWS ");
  			  if (o->u.e.e.rule.rule) {
  				  printf("%s", o->u.e.e.rule.rule->name);
  				  o->u.e.e.rule.rule->used = 1;
  			  }
          else {
  				  printf("%s", o->u.e.e.rule.name);
          }
          printf(" ) )");
        }
        else if (o->u.e.repetition.lo == 1) {
          printf("( *LWS ");
  			  if (o->u.e.e.rule.rule) {
  				  printf("%s", o->u.e.e.rule.rule->name);
  				  o->u.e.e.rule.rule->used = 1;
  			  }
          else {
  				  printf("%s", o->u.e.e.rule.name);
          }
          printf(" *( *LWS \",\" *LWS ");
  			  if (o->u.e.e.rule.rule) {
  				  printf("%s", o->u.e.e.rule.rule->name);
  				  o->u.e.e.rule.rule->used = 1;
  			  }
          else {
  				  printf("%s", o->u.e.e.rule.name);
          }
          printf(" ) )");
        }
        else {
          printf("TODO: something is wrong");
        } 
      }
      else {
        printrep(&o->u.e.repetition);
			  if (o->u.e.e.rule.rule) {
				  printf("%s", o->u.e.e.rule.rule->name);
				  o->u.e.e.rule.rule->used = 1;
			  }
        else {
				  printf("%s", o->u.e.e.rule.name);
        }
      }
 			break;
		case T_GROUP:
			if (tflag)
				printf("{GROUP}");
      if (o->u.e.islist) {
        if (o->u.e.repetition.lo == 0) {
          printf("( [ *LWS ");
          printobj_r(o->u.e.e.group, o->type, tflag);
          printf(" ] *( *LWS \",\" *LWS ");
          printobj_r(o->u.e.e.group, o->type, tflag);
          printf(" ) )");
        }
        else if (o->u.e.repetition.lo == 1) {
          printf("( *LWS ");
          printobj_r(o->u.e.e.group, o->type, tflag);
          printf(" *( *LWS \",\" *LWS ");
          printobj_r(o->u.e.e.group, o->type, tflag);
          printf(" ) )");
        }
        else {
          printf("TODO: something is wrong");
        } 
      }
      else {
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
      }
			break;
		case T_TERMSTR:
			if (tflag)
				printf("{TERMSTR}");
			printrep(&o->u.e.repetition);
			if (o->u.e.e.termstr.flags & F_CASESENSITIVE) {
				unsigned char *p = (unsigned char*)o->u.e.e.termstr.str;
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

void 
parse_from(char *filename) {
	extern FILE *yyin;
	FILE *fin = NULL;
  
	if (filename != NULL) {
		fin = fopen (filename, "rt");
		if (!fin) {
			fprintf(stderr, "input file not found: %s\n", filename);
			exit(1);
		}
    
		input_file = filename;
		yyin = fin;
	}
	else {
		yyin = stdin;
		input_file = "stdin";
	}
  
	scanreset();
	yyparse();
  
	if (fin) fclose(fin);  
}

void
predefine(fn_list *ifile) {
	struct rule *r;
	for (;ifile; ifile = ifile->next) {
		parse_from(ifile->filename);
	}
  
	for (r = rules; r; r = r->next) {
		/* struct without rule definitions are created when names are used
		they are != null when the rule was actually defined */
		if (r->rule) 
			r->predefined = 1;
		else
			r->used = 1;

		if (r->next == rules)
			break;
	}
}

int
summary(void) {
	extern int myerrors;
	if (myerrors > 0) {
		fflush(stdout);
		fprintf(stderr, "parsing failed: %d errors encountered\n", myerrors);
	}
	return myerrors;
}

