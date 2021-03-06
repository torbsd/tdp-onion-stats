#! perl
# rankit.pl - sort inputs by rank (frequency, count) -> report in text or html
# invoke with --help for usage message

use Modern::Perl;
use Getopt::Std;
use Scalar::Util qw(looks_like_number);
use POSIX qw(strftime);

our $DEBUG = 0;
our %RANK;
our @LABELS;
our %COUNT;
our $TOTAL = 0;
our $LINES = 0;
our $LINE = '';
our $SEP = '|';
our $PLAT_OS = 0;
our $PLAT_VERS = 0;
our $PLAT_LIST = 0;
our $VAL_LIST = 0;
our $NO_PERCENT = 0;
our $IS_PERCENT = 0;
our $NO_VALUE = 0;
our %OPTS;
our $THINGCOL = 0;
our $VALCOL = 1;
our $LABEL = undef;
our $REPORT = undef;
our $HTML = 0;
our $DATE = strftime("%Y-%m-%d",localtime(time));
our $NUMFMT = '%.0lf';
our $PERCFMT = '%.1lf%%';
our $MAXLABEL = 50;
our $VERSION = '1.1';

$Getopt::Std::STANDARD_HELP_VERSION = 1;
sub VERSION_MESSAGE { print STDERR qq|rankit.pl v.$VERSION\n|; }
sub HELP_MESSAGE {
	print STDERR <<__HeLP__;
usage: rankit.pl [-HILNOPV] [-t col] [-v col] [-s sep] [-x maxlen]
  Bool opts:
    -H				HTML output (default text)
    -I				value is percentage, dont treat as raw val
    -L                          label is a Perly/Pythonic list (use with -N)
    -N				ignore values, just report counts
    -O				extract OS from label
    -P				do not report percentages in output
    -U                          value is a Perly/Pythonic list
    -V				extract Tor version from label
  Opts with args:
    -x maxlen			max length of label (def 50)
    -l col			extract label from col (default 0)
    -v col			extract value from col (default 1)
    -s sep			use sep as separator for cols (default bar)
  Description:
    Read a stream of rows with the same columns on stdin.  One of the
    columns is or can be transformed into some kind of label, another
    of the columns can be a numeric value associated with the label.
    By default these are columns zero and one, respectively.  The rows
    are binned by label and the values summed per bin; alternatively,
    instead of binning values a simple count per label can be
    accumulated.  The output is sorted by rank (sum of values or
    counts) in descending order.
__HeLP__
}

# so we can figure out which input line causes us to blow up
$SIG{__WARN__} = sub {
	print STDERR "WARNING: @_";
	print STDERR "LINE $LINES: |$LINE|";
};

sub opt { defined($OPTS{$_[0]}) ? $OPTS{$_[0]} : ($_[1] || 0) }

# process command-line args
getopts('DHILNOPUVl:v:s:x:',\%OPTS);
$LABEL	    = shift(@ARGV) if @ARGV;
$REPORT     = shift(@ARGV) if @ARGV;
$DEBUG	    = opt('D');
$HTML	    = opt('H');
$IS_PERCENT = opt('I');
$NO_VALUE   = opt('N');
$PLAT_OS    = opt('O');
$NO_PERCENT = opt('P');
$PLAT_VERS  = opt('V');
$PLAT_LIST  = opt('L');
$VAL_LIST   = opt('U');
$THINGCOL   = int(opt('l',$THINGCOL));
$VALCOL     = int(opt('v',$VALCOL));
$SEP        = opt('s',$SEP);
our $SPLIT  = quotemeta($SEP);
$MAXLABEL   = int(opt('x',$MAXLABEL));
# default $REPORT
unless ($REPORT) {
	$REPORT = "OS" if $PLAT_OS;
	$REPORT = "VERSION" if $PLAT_VERS;
}

sub delist {
	my $thing = shift;
	return undef unless $thing;
	if ((substr($thing,0,1) eq "[") && (substr($thing,-1,1) eq "]")) {
	        return (map { $_ =~ s/(^"|"$)//gs; $_; }
			split(/,/,substr($thing,1,-2)));
	}
	return undef;
}

sub really_rankit {
	my($key,$value) = @_;
	$key = 'null' unless defined $key;
	$key = substr($key,0,$MAXLABEL) if $MAXLABEL;
	$COUNT{$key}++;
	if (looks_like_number($value)) {
		$value = 0+$value;
	} else {
		$value = 1;
	}
	$RANK{$key} += $value;
	$TOTAL += $value;
}

sub rankit {
	my($thing,$value) = @_;
	my $key = $thing;
	if ($PLAT_OS) {
		$key =~ s/^.*on\s//;
		$key = "Windows" if $key =~ /\bWindows\b/;
	} elsif ($PLAT_VERS) {
		$key =~ s/^Tor\s([0-9a-z\.\-]+)\s.*$/$1/;
	} elsif ($PLAT_LIST) {
		my @keys = delist($key);
		really_rankit($_,$value) foreach (@keys);
		return;
	}
	if ($VAL_LIST) {
		my @vals = delist($value);
		return unless @vals;
		foreach my $v (@vals) {
			$v = '?' unless defined $v;
			my $composite = "${key}:${v}";
			really_rankit($composite,1);
		}
		return;
	}
	really_rankit($key,$value);
}

sub html_output {
	print "<!DOCTYPE html>\n";
	print "<HTML>\n";
	print " <HEAD>\n";
	print "  <TITLE>TDP - Tor Statistics - $LABEL by $REPORT</TITLE>\n";
	print "  <STYLE>\n";
	print "div { overflow: visible; }\n";
	print ".chart div {\n";
	print "  font: 12px sans-serif;\n";
	print "  background-color: #cacaca;\n";
	print "  text-align: left;\n";
	print "  padding: 3px;\n";
	print "  margin: 1px;\n";
	print "  color: black;\n";
	print "}\n";
	print "  </STYLE>\n";
	print " </HEAD>\n";
	print " <BODY>\n";
	print "  <H1>$LABEL by $REPORT - $DATE</H1>\n";
	print "  <DIV class='chart'>\n";
	my $fudge = 5;
	foreach (@LABELS) {
		my $r = $RANK{$_};
		my $c = int(100*($r/$TOTAL));
		my $c_ = sprintf("%.2f",100*($r/$TOTAL));
		my $px = sprintf("%dpx",$fudge+($c*10));
		my $n = sprintf("%s (%s%%)",$_,$c_);
		$n =~ s/ /&nbsp;/gs;
		print "   <DIV style='width: $px;'>$n</DIV>\n";
	}
	print "  </DIV>\n";
	print " </BODY>\n";
	print "</HTML>\n";
}

sub text_output {
	my($w) = (sort { $b <=> $a }
		  map { length(sprintf("%s (%d)",$_,$COUNT{$_} || 0)) }
		  (@LABELS,"TOTAL ($LINES)"));

	if ($LABEL) {
		my $paren = ($NO_VALUE || $VAL_LIST) ? "" : " (records)";
		printf("%*s  %s\n",-$w,"${REPORT}${paren}",$LABEL);
		printf("%s  %s\n","=" x $w, "=" x (80 - $w - 3));
	}
	unless ($IS_PERCENT) {
		printf("%*s  ${NUMFMT}\n",-$w,"TOTAL ($LINES)",$TOTAL);
	}
	foreach (@LABELS) {
		my $r = $RANK{$_};
		my $n = ($NO_VALUE || $VAL_LIST) ? "$_" :
			sprintf("%s (%d)",$_,$COUNT{$_});
		if ($NO_PERCENT || $IS_PERCENT) {
			my $fmt = $NUMFMT;
			if ($IS_PERCENT) {
				$r *= 100;
				$fmt = $PERCFMT;
			}
			$r = sprintf($fmt,$r);
			printf("%*s  %s\n",-$w,$n,$r);
		} else {
			my $c = sprintf("${PERCFMT}",100*($r/$TOTAL));
			printf("%*s  ${NUMFMT} (%s)\n",-$w,$n,$r,$c);
		}
	}
}

while (<STDIN>) {
	chomp($LINE = $_);
	my @fields = split($SPLIT,$LINE);
	++$LINES;
	my($thing,$value) = ($fields[$THINGCOL],$fields[$VALCOL]);
	$value = 1 if $NO_VALUE;
	rankit($thing,$value);
}
@LABELS = sort { $RANK{$b} <=> $RANK{$a} } keys %RANK;

if ($HTML) {
	html_output();
} else {
	text_output();
}

1;

__END__
