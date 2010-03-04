use Test::More tests => 174;

use utf8;

use Logfile::Read ();
use Digest::SHA ();
use Cwd ();

my $CWD = Cwd::getcwd();

require 't/lib.pl';

my $DATE = '20100101';
sub rotate_file {
	my $file = shift;
	my $type = shift;
	if ($type eq 'date') {
		ok((rename $file, "$file-$DATE"), "renamed [$file] to [$file-$DATE]");
		$DATE++;
	} elsif ($type eq 'num') {
		for (
			sort { $b <=> $a }
			map { /^(.+\.(.+))$/ ? ( $2 ) : () }
			glob "$file.*") {
			my $next = $_ + 1;
			ok((rename "$file.$_", "$file.$next"), "renamed [$file.$_] to [$file.$next]");
		}
		ok((rename $file, "$file.1"), "renamed [$file] to [$file.1]");
	} else {
		die "Unknown rotate_file type [$type]\n";
	}
	truncate_file($file, "  trucate [$file] by writing nothing");
}

my $i = 1;
for my $type qw( num date ) {

	is(system('rm', '-rf', glob('t/rotate*'), '.logfile-read-status'), 0, 'remove old data');

	my $file = "t/rotate$i";
	my $status_filename = '.logfile-read-status/'
		. Digest::SHA::sha256_hex("$CWD/$file");

	is((-f $file), undef, 'sanity check, the log file should not exist');
	is((-f $status_filename), undef, '  and neither should the status file');

	my $line;

	truncate_file($file);
	append_to_file($file, 'create file we would be reading',
		"line 1.1", "line 1.2");

	my $logfile;
	ok(($logfile = new Logfile::Read($file)), 'open the file as logfile');
	check_status_file($status_filename,
		"File [$file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
		'check that opening the logfile for the first time initiates the status file'
	);

	ok(($line = $logfile->getline()), 'read the first line');
	is($line, "line 1.1\n", '  check the line');
	check_status_file($status_filename,
		"File [$file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
		'check that offset stayed the same'
	);

	rotate_file($file, $type);
	append_to_file($file, 'put content to log file (which was rotated by now, so it is a new file)',
		map "line 2.$_", 1 .. 1000);

	ok(($line = <$logfile>), 'read the second line');
	is($line, "line 1.2\n", '  check the line');

	ok(($line = <$logfile>), 'read the third line, actually first line of the now current file');
	is($line, "line 2.1\n", '  check the line');

	ok($logfile->close, 'close the log file');
	is((undef $logfile), undef, 'undef the object as well');

	check_status_file($status_filename,
		"File [$file] offset [9] checksum [02f64b3c17ca51e9943b3263bf6fb07783922055de233ab22649cc446c33046d]\n",
		'check that offset now points to the end of the first line'
	);

	ok(($logfile = new Logfile::Read($file)), 'open the logfile again');
	ok(($line = <$logfile>), 'read one line (second from the file)');
	is($line, "line 2.2\n", '  check the line');
	rotate_file($file, $type);

	ok(($line = <$logfile>), 'read one line (third from the now-rotated file)');
	is($line, "line 2.3\n", '  check the line');
	is($logfile->commit(), 1, 'commit to status file');

	check_status_file($status_filename,
		"File [$file] offset [27] checksum [a9b882704260e93c4d50f7a7ce76f26c1ffcc061d3fd65aeda20865079cac4e4]\n",
		'check that offset now points to the end of the third line; the object does not know that we are now on the rotated file'
	);

	rotate_file($file, $type);
	append_to_file($file, 'put content to log file',
		"line 4.1");

	ok(($line = <$logfile>), 'read one line (fourth from the yet-another-time-rotated file)');
	is($line, "line 2.4\n", '  check the line');
	is($logfile->commit(), 1, 'commit to status file');

	check_status_file($status_filename,
		"File [$file] offset [36] checksum [cd289aa857f06a7d8c005923298818545885e32d550b57639ca8a5afabf3dd6b]\n",
		'check that offset now points to the end of the second line; we still do not know it has been rotated'
	);

	rotate_file($file, $type);
	append_to_file($file, 'put content to log file',
		map "line 5.$_", 1 .. 5);

	ok(($line = <$logfile>), 'read one more line');
	is($line, "line 2.5\n", '  check the line');

	ok($logfile->close, 'close the log file');
	is((undef $logfile), undef, 'undef the object as well');

	check_status_file($status_filename,
		"File [$file] offset [45] checksum [e4b45b02c352a11022d26aa3d37e42c5c43e0ca85cecefb23d61c0becae07a52]\n",
		'check that offset points to the fifth line'
	);

	ok(($logfile = new Logfile::Read($file)), 'open the logfile yet again');
	ok(($line = <$logfile>), 'read one line');
	is($line, "line 2.6\n", '  check the line');

	is($logfile->close(), 1, 'close the file');
	check_status_file($status_filename,
		"File [$file] archive [@{[ $type eq 'num' ? '.3' : '-20100102' ]}] offset [54] checksum [3fc745f588af1955a409bc1f1cf5aa666c08a19e3c6985eeb345c3921d256820]\n",
		'check that status file now has archive info'
	);
	ok(($logfile = new Logfile::Read($file)), 'and open again, to see processing of status file with archive info');

	my @lines = $logfile->getlines();
	is(scalar(@lines), 1000, 'check number of lines we got');
	is($lines[$#lines], "line 5.5\n", 'check the last line');

	ok($logfile->close, 'close the log file');
	is((undef $logfile), undef, 'undef the object');

	check_status_file($status_filename,
		"File [$file] offset [45] checksum [471663ec09c5520e716a649757dae978a54850d824a15bd63d88d841e0bfc0f5]\n",
		'check that offset points to the end of the log file'
	);
}

