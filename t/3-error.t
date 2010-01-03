
use Test::More tests => 1;

use Logfile::Read ();

my $logfile1;
is(($logfile1 = new Logfile::Read('t/nonexistent')), undef,
	'when opening nonexistent file, open should fail');

