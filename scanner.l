%{
/*
 * Bill's ABNF parser.
 */

#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "y.tab.h"

int yylineno = 1;
int yycolumn = 0;

char badchar;

static void scanrange(char *, int, struct range *);
static char *scanstr(char *, int);

%}

bit	[01]
digit	[0-9]
hexdig	[0-9A-Fa-f]

rulename	[A-Za-z][-0-9A-Za-z]*
wsp	[ \t]

mycrlf	(\n\r|\r\n|\r|\n)

%s SKIP

%%
<SKIP>.*{mycrlf}	{ 	char buf[80];
				sprintf(buf, "Illegal character `%c' - skipping to end of line", badchar);
				yyerror(buf);
				yylineno++;
				yycolumn = 0;
				BEGIN(INITIAL);
				return CRLF; }
\"[ !#-\177]*["\r\n]	{
			char *p;
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext + 1);
			p = &yylval.string[strlen(yylval.string) - 1];
			if (*p == '"')
				*p = '\0';
			/* else warn about unterminated string */
			return CHARVAL;
			}
\<[ -=?-\177]*>		{
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext + 1);
			yylval.string[strlen(yylval.string) - 1] = '\0';
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
{digit}*\*{digit}*	{
			char *ep;

			yycolumn += strlen(yytext);
			yylval.range.lo = strtoul(yytext, &ep, 10);
			if (*ep != '*') {
			    yyerror("internal scanner error 1");
			    yylval.range.hi = -1;
			} else {
			    yylval.range.hi = strtoul(ep + 1, &ep, 10);
			    if (*ep) {
				yyerror("internal scanner error 2");
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
			    yyerror("internal scanner error 3");
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
\|			{ yycolumn++; /* if (!permissive) BEGIN(SKIP); */ return yytext[0]; }
.			{ yycolumn++; badchar = yytext[0]; BEGIN(SKIP); }
%%

static void
scanrange(char *p, int base, struct range *r)
{
	char *ep;

	r->lo = strtoul(p, &ep, base);
	if (r->lo > 255) {
		yyerror("invalid char value");
		r->lo = 0;
		r->hi = 255;
		return;
	}
	if (*ep != '-') {
		yyerror("internal scanner error 4");
		r->hi = r->lo;
		return;
	}
	r->hi = strtoul(ep + 1, &ep, base);
	if (*ep) {
		yyerror("internal scanner error 5");
	}
	if (r->hi > 255) {
		yyerror("invalid char value");
		r->hi = 255;
	}
	if (r->hi < r->lo) {
		yyerror("inverted range");
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
			yyerror("invalid char value");
			i = 255;
		}
		if (i == 0) {
			yyerror("This parser will truncate strings at %x00");
		}
		*b++ = i;
		p = ep + 1;
	} while (*ep == '.');
	if (*ep)
		yyerror("internal scanner error 6");
	*b++ = '\0';
	return strdup(buf);
}
