
use Test::More tests => 32;

use Logfile::Read ();

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

my $line;

truncate_file('t/file');
append_to_file('t/file', 'create file we would be reading',
	'line 1', 'line 2');

my $logfile1;
ok(($logfile1 = new Logfile::Read('t/file')), 'open the file as logfile');

ok(($line = $logfile1->getline()), 'read the first line');
is($line, "line 1\n", '  check the line');
ok(($line = <$logfile1>), 'read the second line');
is($line, "line 2\n", '  check the line');
is(($line = $logfile1->getline()), undef, 'try to read at the end');

append_to_file('t/file', 'append two lines',
	'line 3', 'line 4');

my @lines = <$logfile1>;
is(scalar(@lines), 2, 'check that two lines were read');
is_deeply(\@lines, [ "line 3\n", "line 4\n" ], '  and see what they are'); 

is($logfile1->close, 1, 'close the object');

append_to_file('t/file', 'append three more lines',
	'line 5', 'line 6', 'line 7');

my $logfile2;
ok(($logfile2 = new Logfile::Read('t/file')), 'open the file as logfile');
ok(($line = $logfile2->getline()), 'read one line');
is($line, "line 1\n", '  check the line');
is((undef $logfile2), undef, '  and undef the object');

ok(($logfile2 = new Logfile::Read()), 'create new object without opening');
is($logfile2->getline(), undef, 'getline on unopened object should fail');
is($logfile2->close(), undef, 'close on unopened object should fail');

local *FILE;

ok(tie(*FILE, 'Logfile::Read', 't/file'), 'tie glob to Logfile::Read');
is(ref tied(*FILE), 'Logfile::Read', 'check the type');

ok(($line = <FILE>), 'read the first line');
is($line, "line 1\n", '  check the line');
is((close FILE), 1, 'close the handle');

