
use 5.008000;

use ExtUtils::MakeMaker;
BEGIN {
	eval 'use ExtUtils::MakeMaker::Coverage';
}

WriteMakefile(
	NAME => 'Logfile::Read',
	VERSION_FROM => 'lib/Logfile/Read.pm',
	PREREQ_PM => {
		'Digest::SHA' => 0,
		'Test::More' => 0,
	},
	clean => {
		FILES => [
			'cover_db',
			't/file',
			't/rotate*',
			't/rotfail*',
			'.logfile-read-status',
			'logfile-status-file',
			'.logfile-test3',
		],
	},
	dist => {
		POSTOP => 'mv $(DISTNAME)-$(VERSION).tar.gz ../'
	},
);

