dnl $Fenner: abnf-parser/configure.ac,v 1.4 2004/09/17 01:34:45 fenner Exp $

AC_INIT(bap, 1.0)

AC_PROG_CC
AC_PROG_YACC

dnl The bap -d argument only works with bison, so enable it
dnl  if we're using bison.
if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE, 1, [define if we're using bison])
fi

AC_REPLACE_FUNCS(hcreate)

AC_CONFIG_HEADERS(config.h)

AC_OUTPUT(Makefile)
