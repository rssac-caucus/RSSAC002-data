#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use POSIX;
use File::Path;
use File::Temp;
use YAML;
$|=1;

my $DAYSBACK = 7;
my $DAYSSPAN = 10;
my @LETTERS = ();
my @METRICS = ();

GetOptions (
	"days-back=i" => \$DAYSBACK,
	"days-span=i" => \$DAYSSPAN,
	"letters=s" => \@LETTERS,
	"metrics=s" => \@METRICS,
) or die "usage: $0 --days-back days --days-span days";

@LETTERS = qw (a b c d e f g h i j k l m ) unless @LETTERS;
@METRICS = qw ( load-time rcode-volume traffic-sizes traffic-volume unique-sources zone-size ) unless @METRICS;

print STDERR "LETTERS: ". join(' ', @LETTERS). "\n";
print STDERR "METRICS ". join(' ', @METRICS). "\n";


my $WHEN = (43200+86400*int(time/86400)) - $DAYSBACK * 86400;
my $STOP = $WHEN - $DAYSSPAN * 86400;
my $URL_PREFIXES = {
	a => 'http://a.root-servers.org/rssac-metrics/raw/',
        b => 'http://b.root-servers.org/rssac/',
        c => 'http://c.root-servers.org/rssac002-metrics/',
        d => 'http://droot-web.maxgigapop.net/rssac002/',
        e => 'https://e.root-servers.org/rssac/',
        f => 'http://rssac-stats.isc.org/rssac002/',
        h => 'http://h.root-servers.org/rssac002-metrics/',
        i => 'https://www.netnod.se/rssac002-metrics/',
        j => 'http://j.root-servers.org/rssac-metrics/raw/',
        k => 'https://www-static.ripe.net/dynamic/rssac002-metrics/',
        l => 'http://stats.dns.icann.org/rssac/',
        m => 'https://rssac.wide.ad.jp/rssac002-metrics/',
};
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

sub ymd($) {
	my $t = shift;
	my $Y = POSIX::strftime('%Y', gmtime($t));
	my $M = POSIX::strftime('%m', gmtime($t));
	my $D = POSIX::strftime('%d', gmtime($t));
	return ($Y,$M,$D);
}

sub yaml_fname($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	return "root-$Y$M$D-$m.yaml" if 'zone-size' eq $m && ('a' eq $l || 'j' eq $l);
	return "$l-root-$Y$M$D-$m.yaml";
}

sub tmp_yaml($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	return join('/', $WORKDIR, yaml_fname($t,$l,$m));
}

sub final_yaml($$$) {
	my $t = shift;
	my $l = shift;
	my $m = shift;
	my ($Y,$M,$D) = ymd($t);
	return join('/', $Y, $M, $m, yaml_fname($t,$l,$m));
}

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
			'-o', $tmp_yaml,
			'http://www.disa.mil/G-Root-Stats',
			'-H', "'Host: www.disa.mil'",
			'-H', "'User-Agent: rssac002-fetch.pl'",
			'-H', "'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'",
			'-H', "'Accept-Language: en-US,en;q=0.5'",
			'--compressed',
			'-H', "'Referer: http://www.disa.mil/G-Root-Stats?FilePath=${Y}/${M}/load-time'",
			'-H', "'Content-Type: application/x-www-form-urlencoded'",
			'-H', "'DNT: 1'",
			'-H', "'Connection: keep-alive'",
			'-H', "'Upgrade-Insecure-Requests: 1'",
			'--data', "'scController=Display&scAction=ReadText&FullPath=${Y}%2F${M}%2Fload-time%2Fg-root-${Y}${M}${D}-load-time.yaml'");
	}
	die "no curl_cmd for $t $letter $metric";
}

sub my_mkdir($) {
	my $path = shift;
	my @x = split('/', $path);
	pop @x;
	my $dir = join('/', @x);
	File::Path::make_path($dir);
}

while ($WHEN > $STOP) {
	foreach my $m (@METRICS) {
		foreach my $l (@LETTERS) {
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
			unless (-s $tmp_yaml) {
				print "Received empty file\n";
				next;
			}
			my $yaml;
        		eval { $yaml = YAML::LoadFile($tmp_yaml); };
        		unless ($yaml) {
                		print "Received non-YAML file\n";
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
	$WHEN -= 86400;
}
