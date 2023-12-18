deps:
	cpanm -l local --skip-satisfied --installdeps --notest .
	npm ci

run:
	plackup -r

dev:
	(trap 'kill 0' SIGINT; npm run dev & plackup -r)

build:
	npm run build

test:
	prove -lv -Ilocal/lib/perl5
