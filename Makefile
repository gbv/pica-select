deps:
	cpanm -l local --skip-satisfied --installdeps --notest .
	npm ci

run:
	plackup -r

dev:
	plackup -r & npm run dev

build:
	npm run build

test:
	prove -lv -Ilocal/lib/perl5
