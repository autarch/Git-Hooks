my $gerrit_script = catfile($T, 'gerrit-commit-msg');
    write_file($gerrit_script, {err_mode => 'carp'}, <DATA>)
        or BAIL_OUT("can't write_file('$gerrit_script', <DATA>)\n");
    write_file($msgfile, {err_mode => 'carp'}, $msg)
        or BAIL_OUT("cannot_commit: can't write_file('$msgfile', '$msg')\n");
    write_file($msgfile, {err_mode => 'carp'}, $msg)
        or BAIL_OUT("can_commit: can't write_file('$msgfile', '$msg')\n");
    write_file($msgfile, {err_mode => 'carp'}, $msg)
        or BAIL_OUT("check_can_commit: can't write_file('$msgfile', '$msg')\n");
    system('sh', $gerrit_script, $msgfile);
    write_file($msgfile, {err_mode => 'carp'}, $msg)
        or BAIL_OUT("check_can_commit: can't write_file('$msgfile', '$msg')\n");