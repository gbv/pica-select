deps:
	cpanm -l local --skip-satisfied --installdeps --notest .

run:
	plackup -r -Ilocal/lib/perl5/

test:
	prove -lv -Ilocal/lib/perl5
