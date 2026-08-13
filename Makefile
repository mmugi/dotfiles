MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
LIB_DIR       := $(DOTFILES_ROOT)/lib
CONFIG_DIR    := $(DOTFILES_ROOT)/configs
SHELL_DIR     := $(DOTFILES_ROOT)/shell
SHELL         := /usr/bin/env bash

.DEFAULT_GOAL := help

## Makefile
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"

## Dotfiles
.PHONY: install uninstall uninstall-dryrun
install: ## Install dotfiles.
	@$(SCRIPT_DIR)/dotfiles/install.sh
uninstall: ## Uninstall dotfiles.
	@$(SCRIPT_DIR)/dotfiles/uninstall.sh
uninstall-dryrun: ## Show what would be uninstalled without making any changes.
	@$(SCRIPT_DIR)/dotfiles/uninstall.sh --dryrun

## Git
.PHONY: git-sign
git-sign: ## Configure git commit signing settings.
	@$(SCRIPT_DIR)/git/git-sign.sh

## Shell
#   既定値はスクリプト側にしか置かない。ここで $(or ...) を使って既定を渡すと、
#   利用者が指定したのか既定なのかをスクリプトが区別できなくなり、そのモードで
#   効かない指定の警告が常に出てしまう。
.PHONY: shell-conf shell-print shell-hook
shell-conf: ## Generate shell configuration for every supported shell.
	@$(SCRIPT_DIR)/shell/shellconf.sh $(if $(TARGET_SHELL),--shell $(TARGET_SHELL))
shell-print: ## Print shell config to stdout (TARGET_SHELL and PHASE to override; defaults to bash/rc).
	@$(SCRIPT_DIR)/shell/shellconf.sh $(if $(TARGET_SHELL),--shell $(TARGET_SHELL)) --print $(PHASE)
shell-hook: ## Print the one-line hook to add to your shell rc (TARGET_SHELL to override; defaults to bash).
	@$(SCRIPT_DIR)/shell/shellconf.sh $(if $(TARGET_SHELL),--shell $(TARGET_SHELL)) --hook

## Homebrew
.PHONY: brew-diff brew-dump
brew-diff: ## Show differences between installed brew package and those in the dotfiles Brewfile.
	@$(SCRIPT_DIR)/brew/brew-diff.sh
brew-dump: ## Write all installed packages into a Brewfile in dotfiles.
	@$(SCRIPT_DIR)/brew/brew-dump.sh

## Development
.PHONY: test lint
test: ## Run the bash library smoke tests.
	@bash $(LIB_DIR)/test/smoke.sh
lint: ## Run shellcheck over the bash library, scripts and distributed hooks.
	@shellcheck -s bash $(LIB_DIR)/bash/*.sh $(LIB_DIR)/bash/themes/*.sh \
		$(LIB_DIR)/test/*.sh $(SCRIPT_DIR)/*/*.sh $(SHELL_DIR)/*/*.sh \
		$(DOTFILES_ROOT)/bootstrap.sh $(CONFIG_DIR)/claude/.claude/hooks/*.sh
