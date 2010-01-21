use Test::More tests => 1;

use File::Find ();

my @files;

File::Find::find(sub { push @files, $File::Find::name }, glob(".logfile*"), glob("logfile*"));
@files = sort map { s!^./!! ; $_; } @files;

is_deeply(\@files, [
	'.logfile-read-status',
	'.logfile-test3',
	'.logfile-test3/1f6245dd2a49af539a745de806a543a793a0a13316ae9c72b40d8abc671a390e',
	'logfile-status-file',
	], 'check that only so many files were created');

