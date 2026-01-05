.DEFAULT_GOAL := help
.PHONY = help install clean vendor

help:
	@printf 'This Makefile installs vendor libraries.\n'
	@printf 'Previously installed libraries will be removed before reinstallation.\n'
	@printf 'Please run \033[1;4mmake install\033[m.\n'

install: clean vendor

clean: # Remove vendored libraries.
	@printf '\033[32m>>>\033[m Removing previously installed libraries...\n'
	@find . -maxdepth 1 -mindepth 1 -type d -not -name 'licenses' -exec rm -rf {} \;

vendor: # Install vendored libraries.
	@printf '\033[32m>>>\033[m Installing vendor libraries...\n'
	@pip3 install -t . -r vendor.txt
	@printf '\033[32m>>>\033[m Cleaning up .dist-info directories...\n'
	@rm -rf *.dist-info
