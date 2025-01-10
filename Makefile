MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SHELL         := /usr/bin/env bash

INSTALLER     := $(DOTFILES_ROOT)/install.sh
UNINSTALLER   := $(DOTFILES_ROOT)/uninstall.sh

SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
BREWFILE      := $(DOTFILES_ROOT)/misc/brew/Brewfile


.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"


###  dotfiles  ###

install: ## Download and initialize dotfiles.
#	@DOTFILES_INIT=true $(INSTALLER)
	@$(INSTALLER)
uninstall: ## Uninstall dotfiles.
	@$(UNINSTALLER)

# individual installer tasks

.PHONY: initialize-package-manager install-packages deploy-configs configure_apps
initialize-package-manager: ## Install and configure the package manager.
	@DOTFILES_INIT=true $(INSTALLER) --initialize_package_manager
install-packages: ## Install packages.
	@DOTFILES_INIT=true $(INSTALLER) --install_packages
deploy-configs: ## Create symlinks and directories for dotfiles.
	@DOTFILES_INIT=true $(INSTALLER) --deploy_configs
configure-apps: ## Configure all applications.
	@DOTFILES_INIT=true $(INSTALLER) --configure_apps_all
configure-git: ## Configure Git.
	@DOTFILES_INIT=true $(INSTALLER) --configure_git
configure-starship: ## Configure Starship.
	@DOTFILES_INIT=true $(INSTALLER) --configure_starship


###  utils  ###

.PHONY: brew-list brew-diff
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
