# -*- cperl -*-

use 5.010;
use strict;
use warnings;
use lib 't';
use Test::More tests => 20;
use Path::Tiny;

BEGIN { require "test-functions.pl" };

my ($repo, $file, $clone, $T) = new_repos();

sub setenvs {
    my ($aname, $amail, $cname, $cmail) = @_;
    $ENV{GIT_AUTHOR_NAME}     = $aname;
    $ENV{GIT_AUTHOR_EMAIL}    = $amail || "$ENV{GIT_AUTHOR_NAME}\@example.net";
    $ENV{GIT_COMMITTER_NAME}  = $cname || $ENV{GIT_AUTHOR_NAME};
    $ENV{GIT_COMMITTER_EMAIL} = $cmail || $ENV{GIT_AUTHOR_EMAIL};
    return;
}

sub check_can_commit {
    my ($testname, @envs) = @_;
    setenvs(@envs);

    $file->append($testname);
    $repo->command(add => $file);

    test_ok($testname, $repo, 'commit', '-m', $testname);
}

sub check_cannot_commit {
    my ($testname, $regex, @envs) = @_;
    setenvs(@envs);

    $file->append($testname);
    $repo->command(add => $file);

    if ($regex) {
	test_nok_match($testname, $regex, $repo, 'commit', '-m', $testname);
    } else {
	test_nok($testname, $repo, 'commit', '-m', $testname);
    }
    $repo->command(rm => '--cached', $file);
}

sub check_can_push {
    my ($testname, @envs) = @_;
    setenvs(@envs);

    new_commit($repo, $file, $testname);
    test_ok($testname, $repo, 'push', $clone->repo_path(), 'master');
}

sub check_cannot_push {
    my ($testname, $regex, @envs) = @_;
    setenvs(@envs);

    new_commit($repo, $file, $testname);
    test_nok_match($testname, $regex, $repo, 'push', $clone->repo_path(), 'master');
}


# Repo hooks

install_hooks($repo, undef, 'pre-commit');

$repo->command(config => "githooks.plugin", 'CheckCommit');

# name

$repo->command(qw/config githooks.checkcommit.name valid1/);

$repo->command(qw/config --add githooks.checkcommit.name valid2/);

check_can_commit('allow positive author name', 'valid2');

check_cannot_commit('deny positive author name', qr/does not match any positive/, 'none');
$repo->command(qw/reset --hard HEAD/);

$repo->command(qw/config --add githooks.checkcommit.name !invalid/);

check_can_commit('allow negative author name', 'valid1');

check_cannot_commit('deny negative author name', qr/matches some negative/, 'invalid');
$repo->command(qw/reset --hard HEAD/);

$repo->command(qw/config --remove-section githooks.checkcommit/);

# email

$repo->command(qw/config githooks.checkcommit.email valid1/);

$repo->command(qw/config --add githooks.checkcommit.email valid2/);

check_can_commit('allow positive author email', 'valid2');

check_cannot_commit('deny positive author email', qr/does not match any positive/, 'none');
$repo->command(qw/reset --hard HEAD/);

$repo->command(qw/config --add githooks.checkcommit.email !invalid/);

check_can_commit('allow negative author email', 'valid1');

check_cannot_commit('deny negative author email', qr/matches some negative/, 'invalid');
$repo->command(qw/reset --hard HEAD/);

$repo->command(qw/config --remove-section githooks.checkcommit/);

# canonical
SKIP: {
    use Error ':try';

    try {
        $repo->command(['check-mailmap' => '<joe@example.net>'], {STDERR => 0});
    } otherwise {
        skip "test because the command git-check-mailmap wasn't found", 4;
    };

    my $mailmap = path($T)->child('mailmap');

    $mailmap->spew(<<'EOS');
Good Name <good@example.net> <bad@example.net>
Proper Name <proper@example.net>
EOS

    $repo->command(qw/config githooks.checkcommit.canonical/, $mailmap);

    check_can_commit(
        'allow canonical name and email',
        'Good Name',
        'good@example.net',
    );

    check_cannot_commit(
        'deny non-canonical email',
        qr/identity .*? isn't canonical/,
        'Good Name',
        'bad@example.net',
    );
    $repo->command(qw/reset --hard HEAD/);

    check_cannot_commit(
        'deny non-canonical name',
        qr/identity .*? isn't canonical/,
        'Improper Name',
        'proper@example.net',
    );
    $repo->command(qw/reset --hard HEAD/);

    check_can_commit(
        'allow non-specified email and name',
        'none',
        'none@example.net',
    );

    $repo->command(qw/config --remove-section githooks.checkcommit/);
}

# email-valid
SKIP: {
    unless (eval { require Email::Valid; }) {
        skip "Email::Valid module isn't installed", 2;
    }

    $repo->command(qw/config githooks.checkcommit.email-valid 1/);

    check_can_commit(
        'allow valid email',
        'name',
        'good@example.net',
    );

    check_cannot_commit(
        'deny invalid email',
        qr/failed rfc822 check/,
        'Good Name',
        'bad@example@net',
    );
    $repo->command(qw/reset --hard HEAD/);

    $repo->command(qw/config --remove-section githooks.checkcommit/);
}


# Clone hooks

($repo, $file, $clone, $T) = new_repos();

install_hooks($clone, undef, 'pre-receive');

$clone->command(config => "githooks.plugin", 'CheckCommit');

$clone->command(qw/config githooks.checkcommit.name valid1/);

check_can_push('allow positive author name (push)', 'valid1');

check_cannot_push('deny positive author name (push)', qr/does not match any positive/, 'none');
$repo->command(qw/reset --hard HEAD^/);

# signature
SKIP: {
    skip "signature tests not implemented yet", 4;

    $clone->command(qw/config githooks.checkcommit.signature trusted/);

    check_cannot_push('deny no signature', qr/has NO signature/, 'name');
    $repo->command(qw/reset --hard HEAD^/);

    $file->append('new commit');
    $repo->command(qw/commit -SFIXME -q -a -mcommit/);
    test_ok('allow with signature', $repo, 'push', $clone->repo_path(), 'master');

    $clone->command(qw/config --remove-section githooks.checkcommit/);
}
