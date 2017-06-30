# Tor Statistics #

In the beginning, TDP cranked out some
[quick and dirty statistics](https://torbsd.github.io/dirty-stats.html)
to illustrate the diversity issues in the Tor overlay network, among
other things.  They were generated from the old-style Tor data via
e.g. `blutmagie`, using some simple sh scripts.

Now we've moved on to the next generation, still quick but not so
dirty.  We're using the
[new JSON data](https://onionoo.torproject.org) which gives us the
ability to not only look at this point in time, but at the
[history](https://onionoo.torproject.org/#history) of certain metrics.
It also provides a more convenient interface for querying and
accessing the raw data.

For now we're trying to keep it simple.  There is a Perl script to
produce ranked output from raw data, [rankit.pl](rankit.pl).  This
script is fed by output produced by
[jq](https://stedolan.github.io/jq/) over the raw JSON input data we
get from OnionOO.  Currently we only have point-in-time reports like
the old Quick-and-Dirty ones; the
[simple-reports.sh](simple-reports.sh) script is the driver for
generating these.

Next up will be reports that show how things are changing over various
units of time.  We also will be switching to HTML output from plain
text.  We have not yet integrated these new reports into our web
site... all a work in progress.

Feel free to open Issues with us or ask questions on IRC.

## Dependencies ##

The `simple-reports.sh` script relies on [jq](https://stedolan.github.io/jq/).
Under OpenBSD it is available in ports and can be installed like this:

```
$ doas pkg_add jq
```

The `rankit.pl` script relies on
[Modern::Perl](https://metacpan.org/pod/Modern::Perl).  Under OpeBSD
it can be installed like so:

```
$ doas pkg_add p5-Modern-Perl
```

## Repository Details ##

* [get-all.sh](get-all.sh): download a dump of all current stats into
a date-stamped directory, produce compressed tarball of the result for
easy copying.
* [simple-reports.sh](simple-reports.sh): driver script for the simple,
non-historical reports.  Invokes jq on `details.json` and pump the
results through various invocations of `rankit.pl`.
* [rankit.pl](rankit.pl): Perl script to produce ranked output of
various kinds from raw input data.

The [bplate](bplate) subdirectory contains some boilerplate text
for the various reports.  The [sample](sample) subdir has some
sample reports.

## Usage ##

Our process is as follows:

1. Run `get-all.sh` to produce a directory named `YYYYMMDD`:

```
$ date +%Y%m%d
20170629
$ ./get-all.sh details
# now ./20170629/details.json exists
```

2. Run `simple-reports.sh` to produce .txt reports; by default
they will go in the current directory, but you can use the `--outdir`
option to change this:

```
$ ./simple-reports.sh --indir=20170629 --outdir=20170629
:: generating 20170629/bw-by-os.txt
:: generating 20170629/os-count.txt
:: generating 20170629/cweight-by-os.txt
:: generating 20170629/bw-by-vers.txt
:: generating 20170629/vers-count.txt
:: generating 20170629/cweight-by-vers.txt
:: generating 20170629/bw-by-cc.txt
:: generating 20170629/cweight-by-cc.txt
:: generating 20170629/bw-by-as.txt
:: generating 20170629/bw-by-asn.txt
:: generating 20170629/cweight-by-as.txt
:: generating 20170629/cweight-by-asn.txt
```

Let us know if you have any problems.
