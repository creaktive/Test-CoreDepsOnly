#!/usr/bin/env perl
use strict;
use warnings qw(all);

use Data::Dumper;
use Module::CoreList 2.77;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);

my $doc = PPI::Document->new(@ARGV ? $ARGV[0] : __FILE__);
my $ver = Perl::MinimumVersion->new($doc)->minimum_version;
my $mod = Perl::PrereqScanner->new->scan_ppi_document($doc)->as_string_hash;

delete $mod->{perl};
my $tmp;
my %modver = map { @$_[0 .. 1] } map { (
    defined($tmp = Module::CoreList::removed_from($_))
        && [$_  => dualvar 999 => qq(removed from Perl $tmp)]
) or (
    defined($tmp = Module::CoreList::deprecated_in($_))
        && [$_  => dualvar 999 => qq(deprecated in Perl $tmp)]
) or [
    ($_ => Module::CoreList::first_release($_ => $mod->{$_}))
                => dualvar 999 => q(not in CORE)
] } keys %$mod;

print Dumper {
    map {
        $_ . (
            $mod->{$_}
                ? qq( $mod->{$_})
                : ''
        )   => q...$modver{$_}
    } grep {
        $ver < 0 + $modver{$_}
    } keys %modver
};
print $ver => qq(\n);
