#!/usr/bin/perl

#
# This script fetches RSSAC002 YAML data files from root server operators
#
# The script works by calling curl(1) with the appropriate URL depending
# on the root server, the metric, and the date for each YAML file.
# It begins some number of days in the past (default 7, changable with
# the --skip option) and then works backward for some number of days
# (default 10, changable with the --span option).
#
# Existing files are not re-fetched.  Any new YAML file downloaded is
# (1) verified to be a valid YAML file, and (2) for the correct metric.
# This is necessary because of the way that G-root is publishing YAML
# files.  Note that invalid YAML files are removed and would be re-fetched
# on subsequent runs of this command.
#

use strict;
use warnings;
use Getopt::Long;
use POSIX;
use File::Path;
use File::Temp;
use YAML;
use Date::Parse;
$|=1;

my $SKIP = 7;
my $SPAN = 10;
my $START_DATE = undef;
my $STOP_DATE = undef;
my @LETTERS = ();
my @METRICS = ();

GetOptions (
	"skip=i" => \$SKIP,
	"span=i" => \$SPAN,
	"start-date=s" => \$START_DATE,
	"stop-date=s" => \$STOP_DATE,
	"letters=s" => \@LETTERS,
	"metrics=s" => \@METRICS,
) or die "usage: $0 --skip daysago --span days | --start-date yyyy-mm-dd --stop-date yyyy-mm-dd";

@LETTERS = qw (a b c d e f g h i j k l m ) unless @LETTERS;
@METRICS = qw ( load-time rcode-volume traffic-sizes traffic-volume unique-sources zone-size ) unless @METRICS;

print STDERR "LETTERS: ". join(' ', @LETTERS). "\n";
print STDERR "METRICS ". join(' ', @METRICS). "\n";

#
# For most letters we can do simple HTTP requests based on these URL
# prefixes.  G-root requires something more complex.
#
my $URL_PREFIXES = {
	a => 'https://a.root-servers.org/rssac-metrics/raw/',
        b => 'http://b.root-servers.org/rssac/',
        c => 'https://c.root-servers.org/rssac002-metrics/',
        d => 'http://droot-web.maxgigapop.net/rssac002/',
        e => 'https://e.root-servers.org/rssac/',
        f => 'https://rssac-stats.isc.org/rssac002/',
        h => 'https://h.root-servers.org/rssac002-metrics/',
        i => 'https://www.netnod.se/rssac002-metrics/',
        j => 'https://j.root-servers.org/rssac-metrics/raw/',
        k => 'https://www-static.ripe.net/dynamic/rssac002-metrics/',
        l => 'https://stats.dns.icann.org/rssac/',
        m => 'https://rssac.wide.ad.jp/rssac002-metrics/',
};

#
# These are the unix epoch times corresponding to the earliest
# data files available from each operator.  This prevents the
# script looking for data that does not exist.
#
my $PUB_START = {
	a => 1380499200, # str2time('2013-10-01T00:00:00Z')
	b => 1450051200, # str2time('2015-12-15T00:00:00Z')
	c => 1420416000, # str2time('2015-01-06T00:00:00Z')
	d => 1444953600, # str2time('2015-10-17T00:00:00Z')
	e => 1469923200, # str2time('2016-08-01T00:00:00Z')
	f => 1489017600, # str2time('2017-03-10T00:00:00Z')
	g => 1467849600, # str2time('2016-07-08T00:00:00Z')
	h => 1427328000, # str2time('2015-03-27T00:00:00Z')
	i => 1366588800, # str2time('2013-04-23T10:39:36Z')
	j => 1380499200, # str2time('2013-10-01T00:00:00Z')
	k => 1426464000, # str2time('2015-03-17T00:00:00Z')
	l => 1402704000, # str2time('2014-06-15T00:00:00Z')
	m => 1446249600, # str2time('2015-11-01T00:00:00Z')
};
my $WORKDIR = File::Temp::tempdir( 'workXXXXXXXXX', CLEANUP => 1 );

#
# Covnert unix epoch time into a year,month,day
#
sub ymd($) {
	my $t = shift;
	my $Y = POSIX::strftime('%Y', gmtime($t));
	my $M = POSIX::strftime('%m', gmtime($t));
	my $D = POSIX::strftime('%d', gmtime($t));
	return ($Y,$M,$D);
}

#
# Construct a YAML filename for a letter, metric, and time
#
sub yaml_fname($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	if ('zone-size' eq $m && ('a' eq $l || 'j' eq $l)) {
		return "root-$Y$M$D-$m.yaml" if "$Y-$M-$D" ge '2017-04-01';
	}
	return "$l-root-$Y$M$D-$m.yaml";
}

#
# Construct a temporary local filename for a YAML file
#
sub tmp_yaml($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	return join('/', $WORKDIR, yaml_fname($t,$l,$m));
}

#
# Construct the final path name for a local YAML file
#
sub final_yaml($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	return join('/', $Y, $M, $m, yaml_fname($t,$l,$m));
}

#
# Construct a curl(1) command to fetch a YAML file
#
sub curl_cmd($$$) {
	my $t = shift;
	my $letter = shift;
	my $metric = shift;
	my $tmp_yaml = tmp_yaml($t,$letter,$metric);
	my $final_yaml = final_yaml($t,$letter,$metric);
	my ($Y,$M,$D) = ymd($t);
	if (defined $URL_PREFIXES->{$letter}) {
		return join(' ',
			'curl', '-s', '-S',
			'--connect-timeout', '3',
			'--fail',
			'-o', $tmp_yaml,
			'-H', "'User-Agent: rssac002-fetch.pl'",
			$URL_PREFIXES->{$letter}.$final_yaml);
	}
	if ('g' eq $letter) {
		return join(' ',
			'curl -s -S',
			'--connect-timeout', '3',
			'--fail',
			'--insecure',
			'-o', $tmp_yaml,
			'https://www.disa.mil/G-Root/G-Root-Stats',
			'-H', "'Host: www.disa.mil'",
			'-H', "'User-Agent: rssac002-fetch.pl'",
			'-H', "'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'",
			'-H', "'Accept-Language: en-US,en;q=0.5'",
			'--compressed',
			'-H', "'Referer: http://www.disa.mil/G-Root-Stats?FilePath=${Y}/${M}/${metric}'",
			'-H', "'Content-Type: application/x-www-form-urlencoded'",
			'-H', "'DNT: 1'",
			'-H', "'Connection: keep-alive'",
			'-H', "'Upgrade-Insecure-Requests: 1'",
			'--data', "'scController=Display&scAction=ReadText&FullPath=${Y}%2F${M}%2F${metric}%2Fg-root-${Y}${M}${D}-${metric}.yaml'");
	}
	die "no curl_cmd for $t $letter $metric";
}

#
# Make directory components for a given filename.
#
sub my_mkdir($) {
	my $path = shift;
	my @x = split('/', $path);
	pop @x;
	my $dir = join('/', @x);
	File::Path::make_path($dir);
}

my $START;
my $STOP;
if (defined($START_DATE) && defined($STOP_DATE)) {
	$START = str2time($START_DATE);
	$STOP = str2time($STOP_DATE);
} else {
	$START = time - $SKIP * 86400;
	$STOP = $START - $SPAN * 86400;
}

$START = 43200 + 86400 * int($START/86400);
$STOP  = 43200 + 86400 * int($STOP/86400);

my $NOW = time;
#
# Loop through time, metrics, and letters to fetch YAML files
#
foreach my $l (@LETTERS) {
	foreach my $m (@METRICS) {
		next if 'zone-size' eq $m && 'a' ne $l;
		#
		# Note this is somewhat backwards.  $START is more recent (a larger number)
		# and $STOP is further in the past (a smaller number)
		#
		for (my $WHEN = $START ; $WHEN > $STOP; $WHEN -= 86400) {
			next if $WHEN < $PUB_START->{$l};
			my $final_yaml = final_yaml($WHEN, $l, $m);
			print "$final_yaml ";
			if (-s $final_yaml) {
				print "Already exists\n";
				next;
			}
			
			my $CMD = curl_cmd($WHEN, $l, $m);
			system($CMD);
			die "curl: failed to execute: $!\n" if ($? == -1);
			die sprintf("curl: exited due to signal %d\n", ($? & 127)) if ($? & 127);
			next if $?;
			my $tmp_yaml = tmp_yaml($WHEN, $l, $m);
			if ($l eq 'g') {
				# G-root YAML files sometimes have missing newlines at EOF
				if (open(T, $tmp_yaml) && seek(T, -1, 2)) {
					my $lc;
					sysread(T, $lc, 1);
					unless ($lc eq "\n") {
						print "Adding missing newline; ";
						close(T);
						open(T, ">>$tmp_yaml");
						print T "\n";
					}
					close(T);
				}
			}
			unless (-s $tmp_yaml) {
				print "Received empty file\n";
				next;
			}
			my $yaml;
        		eval { $yaml = YAML::LoadFile($tmp_yaml); };
        		unless ($yaml) {
                		print "Received non-YAML file\n";
				system "cat $tmp_yaml";
				exit(1);
                		next;
        		}
			unless ($yaml->{'metric'} eq $m) {
                		print "Expected metric '$m' but got '". $yaml->{'metric'}. "'\n";
                		next;
			}
			my_mkdir($final_yaml);
                	rename($tmp_yaml, $final_yaml);
			print "Added\n";
		}
	}
}
