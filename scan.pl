#!/usr/bin/env perl
use strict;
use utf8;
use warnings qw(all);

use Module::CoreList 2.77;
use Path::Iterator::Rule;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);

core_deps_only($ARGV[0], qr/^Perl::/x, q(Path::Iterator::Rule));

sub core_deps_only {
    my ($path, @allowed) = @_;

    my $iter = (q(CODE) eq ref $path)
        ? $path
        : Path::Iterator::Rule->new
            ->skip_vcs
            ->skip_dirs(qw(blib))
            ->perl_file
            ->not_name(qr/^(?:Build|Makefile)(?:\.PL)?$/x)
            ->iter($path || q(.));

    my (%maxver, %modver, %provided);
    while (my $file = $iter->()) {
        _scan_file($file, \%maxver, \%modver, \%provided);
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

    for my $modname (sort keys %final) {
        next
            if $provided{$modname}
            or grep {
            q(Regexp) eq ref $_
                ? $modname =~ $_
                : $modname eq $_
        } @allowed;
        printf qq(%s\n\tReason:\t%s\n\tWhere:\t%s\n\n),
            $modname,
            $final{$modname}->{status},
            $final{$modname}->{guilty};
    }

    return;
}

sub _dependency_versions {
    my ($file) = @_;
    my $doc = PPI::Document->new($file);
    my $mod = Perl::PrereqScanner
        ->new
        ->scan_ppi_document($doc)
        ->as_string_hash;

    my $pkgs = $doc->find(q(PPI::Statement::Package));
    my @pkgs = map {
        ($_->children)[2]->content
    } @{$pkgs || []};

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
    return \%status => $mod => \@pkgs;
}

sub _scan_file {
    my ($file, $maxver_ref, $modver_ref, $provided_ref) = @_;
    my ($status, $modver, $pkgs) = _dependency_versions($file);
    ++$provided_ref->{$_} for @$pkgs;
    $modver_ref->{$file} = $modver;

    while (my ($modname, $perlver) = each %{$status}) {
        $maxver_ref->{$modname} = { status => $perlver, guilty => $file }
            if not exists $maxver_ref->{$modname}
            or $maxver_ref->{$modname}->{status} < $perlver;
    }

    return;
}
