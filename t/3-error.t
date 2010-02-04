
use Test::More tests => 23;

use Logfile::Read ();
use Digest::SHA ();
use Cwd ();

my $logfile1;
is(($logfile1 = new Logfile::Read('t/nonexistent')), undef,
	'when opening nonexistent file, open should fail');

my $status_filename = Digest::SHA::sha256_hex(Cwd::getcwd() . '/t/file');

local *TMP;
my $warning;
ok(open(TMP, '>', ".logfile-read-status/$status_filename"),
	'clear the status file');
ok((print TMP "File [strange] offset [145] checksum [xxx]\n"),
	'  put bad logfile name to the status file');
ok(close(TMP), '    and close it');

local $SIG{__WARN__} = sub { $warning = join '', @_; };
is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'try to open the log file when the status file points to different file');
is($warning,
	"Status file [.logfile-read-status/$status_filename] is for file [strange] while expected [@{[ Cwd::getcwd() ]}/t/file]\n",
	'check that warning was issued');

ok(open(TMP, '>', ".logfile-read-status/$status_filename"),
	'clear the status file');
ok((print TMP "Unexpected content\n"),
	'  put content in bad format to the status file');
ok(close(TMP), '    and close it');

is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'try to open the log file when the status file had garbage it in');
is($warning,
	"Status file [.logfile-read-status/$status_filename] has bad format\n",
	'check that warning was issued');

is(system('rm', '-rf', '.logfile-read-status'), 0,
	'remove status directory');

ok(open(TMP, '>', '.logfile-read-status'), '  and create (empty) file instead');
ok(close(TMP), '    and close it');

is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'disabling the status directory should cause opening of the log to fail');
is($warning,
	"Error reading/creating status file [.logfile-read-status/$status_filename]\n",
	'check that warning was issued');

is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file', '<:unknown')), undef,
	'open unknown IO layer should fail');
like($warning,
	qr/^Unknown PerlIO layer "unknown"/,
	'check that warning was issued');

{
no warnings;
*IO::File::new = sub { return };
}
is(($logfile1 = new Logfile::Read('t/file')), undef, 'try to read logfile when IO::File is broken');

