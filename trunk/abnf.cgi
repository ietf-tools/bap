#!/usr/bin/perl
#
# Quick hack to get my abnf parser on the web.
# Sooooo many things to want to fix up.
# Bill Fenner <fenner@fenron.com> 23 June 2004
#
# $Fenner$
#
use CGI qw/:standard/;

print header;
print start_html("Bill's ABNF Parser"), h1("Bill's ABNF Parser");
if (param("abnf")) {
	$abnf = param("abnf");
	$abnf =~ s/\r\n/\n/gm;	# HTTP might use \r\n line seperators
	$tmpabnf = "/tmp/abnf1";
	$tmpparsed = "/tmp/abnf2";
	$tmpprepped = "/tmp/abnf3";
	open(ORIG, ">/tmp/abnf1");
	print ORIG $abnf, "\n";
	close(ORIG);
	open(ERRORS, "/home/fenner/bin/p -c < $tmpabnf 2>&1 >$tmpparsed |");
	@errors = <ERRORS>;
	close(ERRORS);
	if (@errors) {
		print h1("Errors during parsing:");
		print p("Errors are noted by line number and column, e.g. line:column: Something bad.");
		@lines = split(/\n/, $abnf);
		$numlines = @lines;
		$numwidth = length(sprintf("%d", $numlines));
		# XXX I don't think "use CGI" wants me to output my own markup
		print "<pre>\n";
		foreach $error (@errors) {
			if ($error =~ /^(\d+):(\d+):/) {
				$line = $1;
				$col = $2;
				if ($lines[$line - 1]) {
					$lastline = $line;
					while ($line > 0 && $lines[$line - 1] =~ /^(\s|$)/) {
						$line--;
					}
					while ($line <= $lastline) {
						printf("%${numwidth}d: %s\n", $line, htmlify($lines[$line - 1]));
						$line++;
					}
					print " " x ($col + $numwidth + 1), "^\n";
				}
			}
			print htmlify($error);
		}
		print "</pre>\n";
	} else {
		print h1("No errors during parsing.");
	}
	# XXX
	system("/home/fenner/bin/prep $tmpabnf > $tmpprepped");
	print h1("Differences between original and Bill's \"canonical\":");
	print p("There should be very few differences here.  The \"canonical\" output may change 0*1(foo) to [foo], or other equivalences.  If there are any parenthesis added, examine carefully what they surround, as they represent the default concatenation near an alternation which may not not be what you mean.  The original has been processed to facilitate comparison; the processing shouldn't change valid ABNF but can make certain invalid constructs look more invalid.");
	open(DIFF, "/home/fenner/bin/htmlwdiff $tmpprepped $tmpparsed |");
	print <DIFF>;
	close(DIFF);
}
print hr, start_form, p("Enter ABNF Here:");
print p("NOTE: rules must start at column zero.  Remove leading whitespace from non-continuation lines before entering.");
print textarea('abnf', '', 20, 80);
print br, submit, end_form, hr;

sub htmlify($) {
	my($line) = shift;

	$line =~ s/&/\&amp;/g;
	$line =~ s/>/\&gt;/g;
	$line =~ s/</\&lt;/g;
	$line;
}
