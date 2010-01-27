use Test::More tests => 180;

use Logfile::Read ();
use Digest::SHA ();
use Cwd ();

my $CWD = Cwd::getcwd();

sub truncate_file ($;$) {
	my $file = shift;
	local *FILE;
	my $comment = shift;
	if (not defined $comment) {
		$comment = "truncate file [$file] (by opening for write)";
	}
	ok(open(FILE, '>', $file), $comment);
	is(close(FILE), 1, '  and close it');
}

sub append_to_file ($$@) {
	my ($file, $comment) = ( shift, shift );
	local *FILE;
	ok(open(FILE, '>>', $file), $comment);
	my $count = scalar(@_);
	is((print FILE map "$_\n", @_), 1, "  append $count line(s)");
	is(close(FILE), 1, '  and close the file');
}

sub check_status_file ($$$;$) {
	my ($status_file, $expected, $comment, $strict) = @_;
	local *CHECK;
	ok(open(CHECK, $status_file), "open the status file $status_file");
	my $check_status = join '', <CHECK>;
	$expected =~ s!^File \[!File [$CWD/! unless $strict;
	is($check_status, $expected, "  $comment");
	ok(close(CHECK), '  and close it again');
}

is(system('rm', '-rf', 't/file', '.logfile-read-status', '.logfile-test3', 'logfile-status-file'), 0, 'remove old data');

my $status_filename = '.logfile-read-status/'
	. Digest::SHA::sha256_hex("$CWD/t/file");

is((-f 't/file'), undef, 'sanity check, the log file should not exist');
is((-f $status_filename), undef, '  and neither should the status file');

my $line;

truncate_file('t/file');
append_to_file('t/file', 'create file we would be reading',
	'line 1', 'line 2');

my $logfile1;
ok(($logfile1 = new Logfile::Read('t/file')), 'open the file as logfile');
check_status_file($status_filename,
	"File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
	'check that opening the logfile for the first time initiates the status file'
);

ok(($line = $logfile1->getline()), 'read the first line');
is($line, "line 1\n", '  check the line');
check_status_file($status_filename,
	"File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
	'check that offset stayed the same'
);

ok(($line = <$logfile1>), 'read the second line');
is($line, "line 2\n", '  check the line');
is(($line = $logfile1->getline()), undef, 'try to read at the end');

append_to_file('t/file', 'append two lines',
	'line 3', 'line 4');

my @lines = <$logfile1>;
is(scalar(@lines), 2, 'check that two lines were read');
is_deeply(\@lines, [ "line 3\n", "line 4\n" ], '  and see what they are'); 

is($logfile1->close, 1, 'close the object');
is((-f $status_filename), 1, 'check that the status file was created');

check_status_file($status_filename,
	"File [t/file] offset [28] checksum [699793afbd9212c9a54989c189010f21d15273f850ed91de9fae78018393987f]\n",
	'check that the close stored the position in the status file'
);

append_to_file('t/file', 'append three more lines',
	'line 5', 'line 6', 'line 7');

my $logfile2;
ok(($logfile2 = new Logfile::Read('t/file', '<')), 'open the file as logfile');
check_status_file($status_filename,
	"File [t/file] offset [28] checksum [699793afbd9212c9a54989c189010f21d15273f850ed91de9fae78018393987f]\n",
	'check that the status file did not change'
);

ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 5\n", '  check the line');
is((undef $logfile2), undef, '  and undef the object');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'undef of the logfile object should have updated the status file'
);

ok(($logfile2 = new Logfile::Read()), 'create new object without opening');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'no open on logfile object left status file unchanged'
);

is($logfile2->getline(), undef, 'getline on unopened object should fail');
is($logfile2->close(), '', 'close on unopened object should fail');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'close on unopened logfile should not touch the status file'
);

ok(($logfile2 = new Logfile::Read('t/file', { autocommit => 0 })),
	'open the file with autocommit 0');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'no change to the status file'
);
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 6\n", '  check the line');
is($logfile2->close, 1, 'close the object');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'check that no change was written to the status file'
);

ok(($logfile2 = new Logfile::Read('t/file', { autocommit => 0 })),
	'open the file with autocommit 0 again');
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 6\n", '  check the line');
check_status_file($status_filename,
	"File [t/file] offset [35] checksum [52accd0d883d28202a89e2abc6e5be8ead2bcd1d583495b9753fb37e3e668943]\n",
	'check that no change was written to the status file'
);

is($logfile2->commit(), 1, 'explicitly commit');
check_status_file($status_filename,
	"File [t/file] offset [42] checksum [dcf65cfff29e5a15d4abebc8841cb82a43e9ba53e02dc602e8c53d0dc6ad473f]\n",
	'check that offset was committed'
);

my $logfile3;
ok(($logfile3 = new Logfile::Read('t/file', {
	status_file => 'logfile-status-file'
	})), 'open logfile with status_file attribute');
ok(($line = <$logfile3>), 'read line from t/file');
is($line, "line 1\n", '  should get the first one as we use different status file');
is((undef $logfile3), undef, 'undef the object');
check_status_file('.logfile-read-status/logfile-status-file',
	"File [t/file] offset [7] checksum [39d031a6c1c196352ec2aea7fb3dc91ff031888b841d140bc400baa403f2d4de]\n",
	'see custom status file updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '', status_file => 'logfile-status-file'
	})), 'open logfile with status_file attribute, and empty status_dir');
ok(($line = <$logfile3>), 'read line from t/file');
is($line, "line 1\n", '  should get the first one as we use different status file');
is((undef $logfile3), undef, 'undef the object');
check_status_file('logfile-status-file',
	"File [t/file] offset [7] checksum [39d031a6c1c196352ec2aea7fb3dc91ff031888b841d140bc400baa403f2d4de]\n",
	'check that the custom status file was updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '.', status_file => 'logfile-status-file'
	})), 'open logfile with status_file attribute, and current status_dir');
ok(($line = $logfile3->getline()), 'read line from t/file');
is($line, "line 2\n", '  should get the first one as we use different status file');
is(($logfile3 = undef), undef, 'undef the object');
check_status_file('logfile-status-file',
	"File [t/file] offset [14] checksum [9060554863a62b9db5f726216876654e561896071d2e6480f2048b70e0fdadb9]\n",
	'see that the custom status file was updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '.logfile-test3',
	})), 'open logfile with status_dir attribute');
ok(($line = <$logfile3>), 'read line from t/file');
is($line, "line 1\n", '  should get the first one as we use different status file');
is($logfile3->close(), 1, 'close the logfile');
check_status_file('.logfile-test3/' . Digest::SHA::sha256_hex($CWD . '/t/file'),
	"File [t/file] offset [7] checksum [39d031a6c1c196352ec2aea7fb3dc91ff031888b841d140bc400baa403f2d4de]\n",
	'check custom status file updated'
);


ok(($line = $logfile2->getline()), 'read another line');
is($line, "line 7\n", '  check the line');
is($logfile2->close, 1, 'close the object');
check_status_file($status_filename,
	"File [t/file] offset [42] checksum [dcf65cfff29e5a15d4abebc8841cb82a43e9ba53e02dc602e8c53d0dc6ad473f]\n",
	'check that no change was written to the status file since we did not commit explicitly'
);

ok(($logfile2 = new Logfile::Read('t/file')), 'open logfile, will read long line');
# we use the strange 51 here to increase the statement
# test coverage
append_to_file('t/file', 'append two long lines',
	join(' ', ('long line') x 51),
	join(' ', ('very long line') x 1000),
);
ok(($line = $logfile2->getline()), 'read line');
is($line, "line 7\n", '  it should be the one we did not commit the last time');
ok(($line = $logfile2->getline()), 'read another line');
is($line, join(' ', ('long line') x 51) . "\n", '  it should be the long one');
is((undef $logfile2), undef, 'undef the object');
check_status_file($status_filename,
	"File [t/file] offset [559] checksum [ffb67e4c805610e92aece6248949c6675a85d9cc3b7cd061f49800e66e154933]\n",
	'check that undef committed'
);

truncate_file('t/file');
append_to_file('t/file', 'append four lines, one very long',
	'line 1',
	'line 2',
	join(' ', ('very long line') x 1000),
	'line x',
);
ok(($logfile2 = new Logfile::Read('t/file')), 'open logfile, should reset to start because t/file has changed');
check_status_file($status_filename,
	"File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
	'check that the offset was reset'
);
ok(($line = $logfile2->getline()), 'read line');
is($line, "line 1\n", '  it should be the first one');
ok(($line = $logfile2->getline()), 'read another line');
is($line, "line 2\n", '  and check');
ok(($line = $logfile2->getline()), 'read the very long line');
is($line, join(' ', ('very long line') x 1000) . "\n", '  and check that it is the very long one');
is($logfile2->close(), 1, 'close the object');
check_status_file($status_filename,
	"File [t/file] offset [15014] checksum [1ebc1d04872b3b3170cb3dab17d36d96198f5df3851b75a27459a63c882be86a]\n",
	'check that we are now properly set'
);
truncate_file('t/file');
append_to_file('t/file', 'append ten lines',
	map "line $_", 1 .. 10
);

ok(($logfile2 = new Logfile::Read('t/file', { autocommit => 0 })),
	'open logfile with file shorter than it was, and no autocommit');
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 1\n", '  and check line x');
is($logfile2->close(), 1, 'close object');
check_status_file($status_filename,
	"File [t/file] offset [15014] checksum [1ebc1d04872b3b3170cb3dab17d36d96198f5df3851b75a27459a63c882be86a]\n",
	'no autocommit, so should still point to offset 15014'
);

local *FILE;

ok(tie(*FILE, 'Logfile::Read', 't/file'), 'tie glob to Logfile::Read');
is(ref tied(*FILE), 'Logfile::Read', 'check the type');
check_status_file($status_filename,
	"File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
	'check that this tie reset the offset to zero'
);

ok(($line = <FILE>), 'read the first line');
is($line, "line 1\n", '  check the line');
is((close FILE), 1, 'close the handle');
check_status_file($status_filename,
	"File [t/file] offset [7] checksum [39d031a6c1c196352ec2aea7fb3dc91ff031888b841d140bc400baa403f2d4de]\n",
	'and see status file updated'
);

truncate_file($status_filename, 'clear the status file');
append_to_file($status_filename, 'add bogus checksum for offset 0',
	"File [$CWD/t/file] offset [0] checksum [000]\n"
);
ok(($logfile2 = new Logfile::Read('t/file')),
        'open logfile when status file has broken checksum for offset 0');
check_status_file($status_filename,
	"File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
	'check that the checksum got fixed by this open'
);
is($logfile2->close(), 1, 'close object');


{
no warnings;
*Cwd::abs_path = sub { return '/' };
}

ok(($logfile3 = new Logfile::Read('t/file')), 'open logfile when abs_path is broken, returns root');
check_status_file('.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e',
        "File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
        'in this case, the relative file name is used',
	1
);
is($logfile3 = undef, undef, 'undef the object');

{
no warnings;
*Cwd::abs_path = sub { return '/bad/path' };
}

ok(($logfile3 = new Logfile::Read('t/file')), 'open logfile when abs_path is broken, returns nonexistent path');
check_status_file('.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e',
        "File [t/file] offset [0] checksum [e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855]\n",
        'in this case, the relative file name is used',
	1
);
is($logfile3 = undef, undef, 'undef the object');

