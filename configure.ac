dnl $Fenner: abnf-parser/configure.in,v 1.1 2002/07/30 17:06:41 fenner Exp $

AC_INIT(parser.y)

AC_PROG_YACC

if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE)
fi

AC_REPLACE_FUNCS(hcreate)

AC_OUTPUT(Makefile)
