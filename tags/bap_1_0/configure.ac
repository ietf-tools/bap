dnl $Fenner: abnf-parser/configure.ac,v 1.5 2004/09/17 03:14:37 fenner Exp $
dnl
dnl Boy does modern autoconf make it hard to have a small ./configure.
dnl Sorry that it's so huge for almost no configuration.

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
