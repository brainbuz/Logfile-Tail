use Test::More tests => 124;

use Logfile::Read ();
use Digest::SHA ();
use Cwd ();

my $CWD = Cwd::getcwd();

sub truncate_file ($) {
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
	"File [t/file] offset [0]\n",
	'check that opening the logfile for the first time initiates the status file'
);

ok(($line = $logfile1->getline()), 'read the first line');
is($line, "line 1\n", '  check the line');
check_status_file($status_filename,
	"File [t/file] offset [0]\n",
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
	"File [t/file] offset [28]\n",
	'check that the close stored the position in the status file'
);

append_to_file('t/file', 'append three more lines',
	'line 5', 'line 6', 'line 7');

my $logfile2;
ok(($logfile2 = new Logfile::Read('t/file', '<')), 'open the file as logfile');
check_status_file($status_filename,
	"File [t/file] offset [28]\n",
	'check that the status file did not change'
);

ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 5\n", '  check the line');
is((undef $logfile2), undef, '  and undef the object');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'undef of the logfile object should have updated the status file'
);

ok(($logfile2 = new Logfile::Read()), 'create new object without opening');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'no open on logfile object left status file unchanged'
);

is($logfile2->getline(), undef, 'getline on unopened object should fail');
is($logfile2->close(), '', 'close on unopened object should fail');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'close on unopened logfile should not touch the status file'
);

ok(($logfile2 = new Logfile::Read('t/file', { autocommit => 0 })),
	'open the file with autocommit 0');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'no change to the status file'
);
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 6\n", '  check the line');
is($logfile2->close, 1, 'close the object');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'check that no change was written to the status file'
);

ok(($logfile2 = new Logfile::Read('t/file', { autocommit => 0 })),
	'open the file with autocommit 0 again');
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 6\n", '  check the line');
check_status_file($status_filename,
	"File [t/file] offset [35]\n",
	'check that no change was written to the status file'
);

is($logfile2->commit(), 1, 'explicitly commit');
check_status_file($status_filename,
	"File [t/file] offset [42]\n",
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
	"File [t/file] offset [7]\n",
	'see custom status file updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '', status_file => 'logfile-status-file'
	})), 'open logfile with status_file attribute, and empty status_dir');
ok(($line = <$logfile3>), 'read line from t/file');
is($line, "line 1\n", '  should get the first one as we use different status file');
is((undef $logfile3), undef, 'undef the object');
check_status_file('logfile-status-file',
	"File [t/file] offset [7]\n",
	'check that the custom status file was updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '.', status_file => 'logfile-status-file'
	})), 'open logfile with status_file attribute, and current status_dir');
ok(($line = $logfile3->getline()), 'read line from t/file');
is($line, "line 2\n", '  should get the first one as we use different status file');
is(($logfile3 = undef), undef, 'undef the object');
check_status_file('logfile-status-file',
	"File [t/file] offset [14]\n",
	'see that the custom status file was updated'
);

ok(($logfile3 = new Logfile::Read('t/file', {
	status_dir => '.logfile-test3',
	})), 'open logfile with status_dir attribute');
ok(($line = <$logfile3>), 'read line from t/file');
is($line, "line 1\n", '  should get the first one as we use different status file');
is($logfile3->close(), 1, 'close the logfile');
check_status_file('.logfile-test3/' . Digest::SHA::sha256_hex($CWD . '/t/file'),
	"File [t/file] offset [7]\n",
	'check custom status file updated'
);


ok(($line = $logfile2->getline()), 'read another line');
is($line, "line 7\n", '  check the line');
is($logfile2->close, 1, 'close the object');
check_status_file($status_filename,
	"File [t/file] offset [42]\n",
	'check that no change was written to the status file since we did not commit explicitly'
);

local *FILE;

ok(tie(*FILE, 'Logfile::Read', 't/file'), 'tie glob to Logfile::Read');
is(ref tied(*FILE), 'Logfile::Read', 'check the type');

ok(($line = <FILE>), 'read the first line');
is($line, "line 7\n", '  check the line');
is((close FILE), 1, 'close the handle');
check_status_file($status_filename,
	"File [t/file] offset [49]\n",
	'and see status file updated'
);

{
no warnings;
*Cwd::abs_path = sub { return '/' };
}

ok(($logfile3 = new Logfile::Read('t/file')), 'open logfile when abs_path is broken, returns root');
check_status_file('.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e',
        "File [t/file] offset [0]\n",
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
        "File [t/file] offset [0]\n",
        'in this case, the relative file name is used',
	1
);
is($logfile3 = undef, undef, 'undef the object');

