#!/usr/bin/env perl
use strict;
use warnings qw(all);

use Data::Dumper;
use Module::CoreList;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);

my $doc = PPI::Document->new(@ARGV ? $ARGV[0] : __FILE__);
my $ver = Perl::MinimumVersion->new($doc)->minimum_version;
my $mod = Perl::PrereqScanner->new->scan_ppi_document($doc)->as_string_hash;
delete $mod->{perl};

my %modver = map {
    defined Module::CoreList::removed_from($_) 
        ? ($_ => dualvar 999 => q(removed from CORE))
        : ($_ => (
            Module::CoreList::first_release($_ => $mod->{$_})
              => dualvar 999 => q(not in CORE)
        ) [0])
} keys %$mod;

print $ver, qq(\n);
print Dumper {
    map  { $_   => q...$modver{$_} }
    grep { $ver  < 0 + $modver{$_} }
    keys %modver
};
