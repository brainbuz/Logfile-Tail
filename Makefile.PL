
use 5.008;

use ExtUtils::MakeMaker;

use Devel::AssertOS qw( -MSWin32 -Cigwin);

BEGIN {
	eval 'use ExtUtils::MakeMaker::Coverage';
}

WriteMakefile(
	NAME => 'Logfile::Tail',
	LICENSE => 'GPLv2+ or Artistic_2',
	VERSION_FROM => 'lib/Logfile/Tail.pm',
	PREREQ_PM => {
		'Digest::SHA' => 0,
		'Test::More' => 0,
	},
	EXE_FILES => [  ],
	clean => {
		FILES => [
			'cover_db',
			't/file',
			't/rotate*',
			't/rotfail*',
			't/status-file2',
			'.logfile-tail-status',
			'logfile-status-file',
			'.logfile-test3',
		],
	},
	dist => {
		POSTOP => 'mv $(DISTNAME)-$(VERSION).tar.gz ../'
	},
);

