
use 5.008;

use ExtUtils::MakeMaker;

BEGIN {
  if ( $^O =~ /^MSWin32$|^cygwin$/i) {
    die "Unsupported OS!\n";
  }
	eval 'use ExtUtils::MakeMaker::Coverage';
}

WriteMakefile(
	NAME => 'Logfile::Tail',
  LICENSE => 'perl',
	VERSION_FROM => 'lib/Logfile/Tail.pm',
	PREREQ_PM => {
		'Digest::SHA' => 0,
		'Test::More' => 0,
		'File::Spec' => 0,
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

