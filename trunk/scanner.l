%{
/*
 * Bill's ABNF parser.
 * Copyright 2002-2004 William C. Fenner <fenner@research.att.com>
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
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "y.tab.h"

static const char rcsid[] =
 "$Fenner: abnf-parser/scanner.l,v 1.13 2004/10/11 17:14:11 fenner Exp $";

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

%x SKIP

/* line number isn't quite being updated properly.
   suspect unterminated charval and prosevals. */
%%
<SKIP>.*{mycrlf}	{ 	char q = (badchar == '\'') ? '"' : '\'';
				mywarn(MYERROR, "Illegal character %c%c%c - skipping to end of line", q, badchar, q);
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
				mywarn(MYERROR, "unterminated char-val");
				unput(*p);	/* put the cr or lf back */
			}
			*p = '\0';
			if (*yylval.string == '\0')
				mywarn(MYWARNING, "zero-length char-val");
			return CHARVAL;
			}
\<{proseval}[>\r\n]	{
			char *p;
			yycolumn += strlen(yytext);
			yylval.string = strdup(yytext + 1);
			p = &yylval.string[strlen(yylval.string) - 1];
			if (*p != '>') {
				mywarn(MYERROR, "unterminated prose-val");
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
%b{bit}+(-|\.\.){bit}+		{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 2, &yylval.range);
			return BINVALRANGE;
			}
%b{bit}+(\.{bit}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 2);
			return BINVAL;
			}
%b.			{ mywarn(MYERROR, "bad bit value");
			  badchar = yytext[2]; BEGIN(SKIP); }
%d{digit}+(-|\.\.){digit}+	{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 10, &yylval.range);
			return DECVALRANGE;
			}
%d{digit}+(\.{digit}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 10);
			return DECVAL;
			}
%d.			{ mywarn(MYERROR, "bad decimal value");
			  badchar = yytext[2]; BEGIN(SKIP); }
%x{hexdig}+(-|\.\.){hexdig}+	{
			yycolumn += strlen(yytext);
			scanrange(yytext + 2, 16, &yylval.range);
			return HEXVALRANGE;
			}
%x{hexdig}+(\.{hexdig}+)*	{
			yycolumn += strlen(yytext);
			yylval.string = scanstr(yytext + 2, 16);
			return HEXVAL;
			}
%x.			{ mywarn(MYERROR, "bad hex value");
			  badchar = yytext[2]; BEGIN(SKIP); }
{digit}*\*{digit}*	{
			char *ep;

			yycolumn += strlen(yytext);
			yylval.range.lo = strtoul(yytext, &ep, 10);
			if (*ep != '*') {
			    mywarn(MYERROR, "internal scanner error 1");
			    yylval.range.hi = -1;
			} else {
			    yylval.range.hi = strtoul(ep + 1, &ep, 10);
			    if (*ep) {
				mywarn(MYERROR, "internal scanner error 2");
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
			    mywarn(MYERROR, "internal scanner error 3");
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
	if (*ep != '-' && *ep != '.') {
		mywarn(MYERROR, "internal scanner error 4");
		r->hi = r->lo;
		return;
	}
	if (*ep == '.') {
		if (!permissive) {
			badchar = '.';
			BEGIN(SKIP);
		}
		mywarn(MYERROR, "Ranges use \"-\", not \"..\".");
		ep++;
	}
	r->hi = strtoul(ep + 1, &ep, base);
	if (*ep) {
		mywarn(MYERROR, "internal scanner error 5");
	}
	if (r->hi < r->lo) {
		mywarn(MYERROR, "inverted range");
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
		if (i > 255) {	/* XXX */
			mywarn(MYWARNING, "I can't handle this legal ABNF char value");
			i = 255;
		}
		if (i == 0) {
			mywarn(MYERROR, "This parser will truncate strings at %x00");
		}
		*b++ = i;
		p = ep + 1;
	} while (*ep == '.');
	if (*ep)
		mywarn(MYERROR, "internal scanner error 6");
	*b++ = '\0';
	return strdup(buf);
}
