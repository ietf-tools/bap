dnl $Fenner$

AC_REVISION($Fenner$)
AC_INIT(parser.y)

AC_PROG_YACC

if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE)
fi

AC_REPLACE_FUNCS(hcreate)

AC_OUTPUT(Makefile)
