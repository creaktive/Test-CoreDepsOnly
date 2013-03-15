#!/usr/bin/env perl
use 5.010;
use strict;
use warnings qw(all);

use Data::Printer;

use Module::CoreList;
use Perl::MinimumVersion;
use Perl::PrereqScanner;

my $d = PPI::Document->new($ARGV[0]);
my $v = Perl::MinimumVersion->new($d)->minimum_version;
my $m = Perl::PrereqScanner->new->scan_ppi_document($d)->as_string_hash;
delete $m->{perl};

my %v = map {
    defined(Module::CoreList->removed_from($_))
        ? ($_ => 999)
        : ($_ => Module::CoreList->first_release($_ => $m->{$_}) // 998)
} keys %$m;

&p({
    map { $_ => $v{$_} }
    grep { $v < $v{$_} }
    keys %v
});
