%{
/*
 * Bill's ABNF parser.
 */

#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "y.tab.h"

static const char rcsid[] =
 "$Fenner: abnf-parser/scanner.l,v 1.8 2002/07/30 17:05:01 fenner Exp $";

int yylineno = 1;
int yycolumn = 0;
extern int permissive;

char badchar;

static void scanrange(char *, int, struct range *);
static char *scanstr(char *, int);

%}

bit		[01]
digit		[0-9]
hexdig		[0-9A-Fa-f]

rulename	[A-Za-z][-0-9A-Za-z]*
wsp		[ \t]

/* *(%x20-21 / %x23-7E) */
charval		[ !#-~]*

/* *(%x20-3D / %x3F-7E) */
proseval	[ -=?-~]*

mycrlf	(\n\r|\r\n|\r|\n)

%s SKIP

/* line number isn't quite being updated properly.
   suspect unterminated charval and prosevals. */
%%
<SKIP>.*{mycrlf}	{ 	char q = (badchar == '\'') ? '"' : '\'';
				mywarn("Illegal character %c%c%c - skipping to end of line", q, badchar, q);
				yylineno++;
				yycolumn = 0;
				BEGIN(INITIAL);
				return CRLF; }
\"{charval}["\r\n]	{
			char *p;
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext + 1);
			p = &yylval.string[strlen(yylval.string) - 1];
			if (*p != '"') {
				mywarn("unterminated char-val");
				unput(*p);	/* put the cr or lf back */
			}
			*p = '\0';
			if (*yylval.string == '\0')
/* warning only */		mywarn("zero-length char-val");
			return CHARVAL;
			}
\<{proseval}[>\r\n]	{
			char *p;
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext + 1);
			p = &yylval.string[strlen(yylval.string) - 1];
			if (*p != '>') {
				mywarn("unterminated prose-val");
				unput(*p);	/* put the cr or lf back */
			}
			*p = '\0';
			return PROSEVAL;
			}
{rulename}		{
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext);
			return RULENAME;
			}
%b{bit}+-{bit}+		{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 2, &yylval.range);
			return BINVALRANGE;
			}
%b{bit}+(\.{bit}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 2);
			return BINVAL;
			}
%b.			{ mywarn("bad bit value");
			  badchar = yytext[2]; BEGIN(SKIP); }
%d{digit}+-{digit}+	{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 10, &yylval.range);
			return DECVALRANGE;
			}
%d{digit}+(\.{digit}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 10);
			return DECVAL;
			}
%d.			{ mywarn("bad decimal value");
			  badchar = yytext[2]; BEGIN(SKIP); }
%x{hexdig}+-{hexdig}+	{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 16, &yylval.range);
			return HEXVALRANGE;
			}
%x{hexdig}+(\.{hexdig}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 16);
			return HEXVAL;
			}
%x.			{ mywarn("bad hex value");
			  badchar = yytext[2]; BEGIN(SKIP); }
{digit}*\*{digit}*	{
			char *ep;

			yycolumn += strlen(yytext);
			yylval.range.lo = strtoul(yytext, &ep, 10);
			if (*ep != '*') {
			    mywarn("internal scanner error 1");
			    yylval.range.hi = -1;
			} else {
			    yylval.range.hi = strtoul(ep + 1, &ep, 10);
			    if (*ep) {
				mywarn("internal scanner error 2");
				yylval.range.hi = -1;
			    } else if (yylval.range.hi == 0)
				yylval.range.hi = -1;
			}
			return REPEAT;
			}
{digit}+		{
			char *ep;

			yycolumn += strlen(yytext);
			yylval.range.hi = yylval.range.lo = strtoul(yytext, &ep, 10);
			if (*ep) {
			    mywarn("internal scanner error 3");
			    yylval.range.hi = yylval.range.lo = 42;
			}
			return REPEAT;
			}
=\/			{ yycolumn += 2; return EQSLASH; }
({wsp}+|(;[^\r\n]*)|{mycrlf}{wsp}+)+	{ char *p = yytext;
				while (*p) {
					if (*p == '\r') {
						yylineno++;
						yycolumn = 0;
						if (*(p+1) == '\n')
							p++;
					}
					if (*p == '\n') {
						yylineno++;
						yycolumn = 0;
						if (*(p+1) == '\r')
							p++;
					}
					p++;
					yycolumn++;
				}
				return CWSP; }
{mycrlf}		{ yylineno++; yycolumn = 0; return CRLF; }
[][()=/]		{ yycolumn++; return yytext[0]; }
\|			{ yycolumn++;
			  if (!permissive) {
				badchar = yytext[0];
				BEGIN(SKIP);
			  }
			  return yytext[0]; }
.			{ yycolumn++; badchar = yytext[0]; BEGIN(SKIP); }
%%

static void
scanrange(char *p, int base, struct range *r)
{
	char *ep;

	r->lo = strtoul(p, &ep, base);
	if (r->lo > 255) {
		mywarn("invalid char value");
		r->lo = 0;
		r->hi = 255;
		return;
	}
	if (*ep != '-') {
		mywarn("internal scanner error 4");
		r->hi = r->lo;
		return;
	}
	r->hi = strtoul(ep + 1, &ep, base);
	if (*ep) {
		mywarn("internal scanner error 5");
	}
	if (r->hi > 255) {
		mywarn("invalid char value");
		r->hi = 255;
	}
	if (r->hi < r->lo) {
		mywarn("inverted range");
	}
	return;
}

static char *
scanstr(char *p, int base)
{
	char *ep;
	char buf[512];	/*XXX*/
	char *b = buf;
	int i;

	do {
		i = strtoul(p, &ep, base);
		if (i > 255) {
			mywarn("invalid char value");
			i = 255;
		}
		if (i == 0) {
			mywarn("This parser will truncate strings at %x00");
		}
		*b++ = i;
		p = ep + 1;
	} while (*ep == '.');
	if (*ep)
		mywarn("internal scanner error 6");
	*b++ = '\0';
	return strdup(buf);
}
