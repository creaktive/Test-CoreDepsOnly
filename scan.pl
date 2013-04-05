#!/usr/bin/env perl
use strict;
use warnings qw(all);

use Data::Dumper;

use Module::CoreList 2.77;
use Path::Iterator::Rule;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);

my $rule = Path::Iterator::Rule->new
    ->skip_vcs
    ->skip_dirs(qw(blib))
    ->perl_file
    ->not_name(qr/^(?:Build|Makefile)(?:\.PL)?$/x);
#my $iter = $rule->iter(q(../rainbarf));
my $iter = $rule->iter(q(.));

my (%maxver, %modver);
while (my $file = $iter->()) {
    my ($status, $modver) = dependency_versions($file);
    $modver{$file} = $modver;
    while (my ($modname, $perlver) = each %{$status}) {
        $maxver{$modname} = { status => $perlver, guilty => $file }
            if not exists $maxver{$modname}
            or $maxver{$modname}->{status} < $perlver;
    }
}

my %final;
for my $modname (keys %maxver) {
    next if $maxver{perl}->{status} >= $maxver{$modname}->{status};
    my $info = $maxver{$modname};
    my $guilty = $info->{guilty};
    $modname .= qq( $modver{$guilty}->{$modname})
        if $modver{$guilty}->{$modname};
    $final{$modname} = $info;
}

print Dumper \%final;

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
