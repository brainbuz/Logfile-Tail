
use Test::More tests => 19;

use Logfile::Read ();

my $logfile1;
is(($logfile1 = new Logfile::Read('t/nonexistent')), undef,
	'when opening nonexistent file, open should fail');

local *TMP;
my $warning;
ok(open(TMP, '>', '.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e'),
	'clear the status file');
ok((print TMP "File [strange] offset [145]\n"),
	'  put bad logfile name to the status file');
ok(close(TMP), '    and close it');

local $SIG{__WARN__} = sub { $warning = join '', @_; };
is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'try to open the log file when the status file points to different file');
is($warning,
	"Status file [.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e] is for file [strange] while expected [t/file]\n",
	'check that warning was issued');

ok(open(TMP, '>', '.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e'),
	'clear the status file');
ok((print TMP "Unexpected content\n"),
	'  put content in bad format to the status file');
ok(close(TMP), '    and close it');

is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'try to open the log file when the status file had garbage it in');
is($warning,
	"Status file [.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e] has bad format\n",
	'check that warning was issued');

is(system('rm', '-rf', '.logfile-read-status'), 0,
	'remove status directory');

ok(open(TMP, '>', '.logfile-read-status'), '  and create (empty) file instead');
ok(close(TMP), '    and close it');

is($warning = undef, undef, 'clear any warnings');
is(($logfile1 = new Logfile::Read('t/file')), undef,
	'disabling the status directory should cause opening of the log to fail');
is($warning,
	"Error reading/creating status file [.logfile-read-status/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e]\n",
	'check that warning was issued');

