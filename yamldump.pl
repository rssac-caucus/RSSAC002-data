#!/usr/bin/env perl
use strict;
use warnings;
use YAML;
use Data::Dumper;

my $f = shift || die "usage: $0 yamlfile\n";

my $hashref = YAML::LoadFile($f);
print Dumper $hashref;
