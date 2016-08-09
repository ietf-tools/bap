AC_INIT(bap, 1.4)

AC_PROG_CC
AC_PROG_YACC

dnl byacc on FreeBSD 4.3 gives weird parsing problems.
dnl byacc on FreeBSD 4.10 seems fine.
if test "$ac_cv_prog_YACC" = "byacc"; then
	AC_WARN([using byacc has caused inexplicable runtime behavior;])
	AC_WARN([if you get incomprehensible errors when parsing])
	AC_WARN([grammars, install bison and try again.])
fi

dnl The bap -d argument only works with bison, so enable it
dnl  if we're using bison.
dnl
if test "$ac_cv_prog_YACC" = "bison -y"; then
	AC_DEFINE(YYERROR_VERBOSE, 1, [define if we're using bison])
fi

AC_PROG_LEX
if test "$ac_cv_prog_LEX" = ":"; then
        AC_ERROR([please install flex])
fi

dnl web bin dir
AC_MSG_CHECKING([where to put web binaries])
AC_ARG_WITH([web-bin-dir],
	[AS_HELP_STRING([--with-web-bin-dir=DIR],
		[specify where cgi and helpers get installed])],
	[],
	[with_web_bin_dir=.])
AS_IF([test "x$with_web_bin_dir" = xyes -o "x$with_web_bin_dir" = xno],
	[AC_MSG_FAILURE([specify a pathname to --with-web-bin-dir])])
AC_SUBST(WEBBINDIR, [$with_web_bin_dir])
AC_MSG_RESULT([$with_web_bin_dir])

dnl web diff program: default is web bin dir + /htmlwdiff
AC_MSG_CHECKING([for web diff program])
AC_ARG_WITH([web-diff],
	[AS_HELP_STRING([--with-web-diff=COMMAND],
		[specify the full command line for the desired web diff])],
	[],
	[with_web_diff=${with_web_bin_dir}/htmlwdiff])
AS_IF([test "x$with_web_diff" = xyes -o "x$with_web_diff" = xno],
	[AC_MSG_FAILURE([specify a full command as argument to --with-web-diff])])
AC_SUBST(WEBDIFF, [$with_web_diff])
AC_MSG_RESULT($with_web_diff)

AC_REPLACE_FUNCS(hcreate)

AC_CONFIG_HEADERS(config.h)

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([tests/baptest abnf.cgi], [chmod +x tests/baptest])
AC_OUTPUT
