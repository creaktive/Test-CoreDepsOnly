#!/usr/bin/env perl
use strict;
use utf8;
use warnings qw(all);

use Module::CoreList 2.77;
use Path::Iterator::Rule;
use Perl::MinimumVersion;
use Perl::PrereqScanner;
use Scalar::Util qw(dualvar);
use Test::Builder;

all_core_deps_only_ok($ARGV[0], qr/^Perl::/x, q(Path::Iterator::Rule));

sub all_core_deps_only_ok {
    my ($path, @allowed) = @_;

    my $Test = Test::Builder->new;
    my ($final, $whitelist) = core_deps_only($path);

    @allowed = grep {
        q(Regexp) eq ref $_
        or not ++$whitelist->{$_}
    } @allowed;

    for my $modname (sort keys %$final) {
        next
            if $whitelist->{$modname}
            or grep { $modname =~ $_ } @allowed;

        $Test->ok(0 => $final->{$modname}{where});
        $Test->diag(qq(\t$modname => $final->{$modname}{reason}));
    }

    return;
}

sub core_deps_only {
    my ($path) = @_;

    my $iter = (q(CODE) eq ref $path)
        ? $path
        : Path::Iterator::Rule->new
            ->skip_vcs
            ->skip_dirs(qw(blib eg examples))
            ->perl_file
            ->not_name(qr{^(?:author|release).+\.t$}x)
            ->iter($path || q(.));

    my (%maxver, %modver, %whitelist);
    while (my $file = $iter->()) {
        _scan_file($file, \%maxver, \%modver, \%whitelist);
    }

    my %final;
    for my $modname (keys %maxver) {
        next if $maxver{perl}->{reason} >= $maxver{$modname}->{reason};
        my $info = $maxver{$modname};
        my $where = $info->{where};
        $modname .= qq( $modver{$where}->{$modname})
            if $modver{$where}->{$modname};
        $final{$modname} = $info;
    }

    return \%final => \%whitelist;
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
    my %reason = map { @$_[0 .. 1] } map { (
        defined($tmp = Module::CoreList::removed_from($_))
            && [$_  => dualvar 999 => qq(removed from Perl $tmp)]
    ) or (
        defined($tmp = Module::CoreList::deprecated_in($_))
            && [$_  => dualvar 999 => qq(deprecated in Perl $tmp)]
    ) or [
        ($_ => Module::CoreList::first_release($_ => $mod->{$_}))
                    => dualvar 999 => q(not in CORE)
    ] } keys %$mod;

    $reason{perl} = $mod->{perl} = $ver;
    return \%reason => $mod => \@pkgs;
}

sub _scan_file {
    my ($file, $maxver_ref, $modver_ref, $provided_ref) = @_;
    my ($reason, $modver, $pkgs) = _dependency_versions($file);
    ++$provided_ref->{$_} for @$pkgs;
    $modver_ref->{$file} = $modver;

    while (my ($modname, $perlver) = each %{$reason}) {
        $maxver_ref->{$modname} = { reason => $perlver, where => $file }
            if not exists $maxver_ref->{$modname}
            or $maxver_ref->{$modname}->{reason} < $perlver;
    }

    return;
}
