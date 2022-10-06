deps:
	cpanm -l local --skip-satisfied --installdeps --notest .

run:
	plackup -r

dev:
	plackup -r & npm run dev

test:
	prove -lv -Ilocal/lib/perl5
