MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SHELL         = /usr/bin/env bash

INSTALLER     := $(DOTFILES_ROOT)/install.sh
UNINSTALLER   := $(DOTFILES_ROOT)/uninstall.sh

SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
BREWFILE      := $(DOTFILES_ROOT)/misc/brew/Brewfile


.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"


###  dotfiles  ###
.PHONY: install uninstall
install: ## Install dotfiles.
	@$(INSTALLER)
uninstall: ## Uninstall dotfiles.
	@$(UNINSTALLER)

# individual installer tasks

.PHONY: deploy-configs initialize-package-manager install-packages configure-apps configure-git configure-starship configure-tpm
deploy-configs: ## Create symlinks and directories for dotfiles.
	@$(INSTALLER) --deploy-configs
initialize-package-manager: ## Install and configure the package manager.
	@DOTFILES_INIT=true $(INSTALLER) --initialize-package-manager
install-packages: ## Install packages.
	@DOTFILES_INIT=true $(INSTALLER) --install-packages
configure-apps: ## Configure all applications.
	@DOTFILES_INIT=true $(INSTALLER) --configure-apps-all
configure-git: ## Configure Git.
	@DOTFILES_INIT=true $(INSTALLER) --configure-git
configure-starship: ## Configure Starship.
	@DOTFILES_INIT=true $(INSTALLER) --configure-starship
configure-tpm: ## Configure Tmux Plugin Manager.
	@DOTFILES_INIT=true $(INSTALLER) --configure-tpm

# individual uninstaller tasks

.PHONY: delete-configs
delete-configs: ## Delete symlinks and directories for dotfiles.
	@$(UNINSTALLER) --delete-configs


###  utils  ###

.PHONY: brew-list brew-dump brew-diff
brew-list: ## List all packages managed by the Brewfile in dotfiles.
	@cat "$(BREWFILE)"
brew-dump: ## Write all installed packages into a Brewfile in dotfiles.
	@$(SCRIPT_DIR)/make/brew-dump.sh "$(BREWFILE)"
brew-diff: ## Show differences between installed brew package and those in the dotfiles Brewfile.
	@brew bundle dump --global --force
	@if type git >/dev/null 2>&1; then \
             git diff "${HOME}/.Brewfile" "$(BREWFILE)"; \
         else \
             diff -u "${HOME}/.Brewfile" "$(BREWFILE)"; \
         fi || true
