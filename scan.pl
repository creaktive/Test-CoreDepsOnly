#!/usr/bin/env perl
use strict;
use warnings qw(all);

use Data::Dumper;
use Module::CoreList 2.77;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);

my ($status, $modver) = dependency_versions(@ARGV ? $ARGV[0] : __FILE__);
print Dumper {
    map {
        $_ . (
            $modver->{$_}
                ? qq( $modver->{$_})
                : ''
        )   => q...$status->{$_}
    } grep {
        $status->{perl} < 0 + $status->{$_}
    } keys %$status
};

sub dependency_versions {
    my ($file) = @_;
    my $doc = PPI::Document->new($file);
    my $mod = Perl::PrereqScanner->new->scan_ppi_document($doc)->as_string_hash;

    my $ver = defined $mod->{perl}
        ? delete $mod->{perl}
        : Perl::MinimumVersion->new($doc)->minimum_version;
    $ver = $ver->numify if q(version) eq ref $ver;

    my $tmp;
    my %status = map { @$_[0 .. 1] } map { (
        defined($tmp = Module::CoreList::removed_from($_))
            && [$_  => dualvar 999 => qq(removed from Perl $tmp)]
    ) or (
        defined($tmp = Module::CoreList::deprecated_in($_))
            && [$_  => dualvar 999 => qq(deprecated in Perl $tmp)]
    ) or [
        ($_ => Module::CoreList::first_release($_ => $mod->{$_}))
                    => dualvar 999 => q(not in CORE)
    ] } keys %$mod;

    $status{perl} = $mod->{perl} = $ver;
    return \%status => $mod;
}
