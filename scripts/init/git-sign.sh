#!/usr/bin/env bash

set -ueo pipefail

trap 'echo; echo "Interrupted."; exit 130' INT

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import util msg log

_git_config_chk() {
  local key="$1"
  local config
  if config="$(git config --global --get "$key")"; then
    printf '%s' "$config"
    return 0
  else
    return 1
  fi
}

_git_config_set() {
  local key="$1" value="$2"
  git config --global "$key" "$value"
  msg::notice --configured "${key}: ${value}"
}

configure_signing_format() {
  local config signing_format

  msg 'configuring signing format.'

  if config="$(_git_config_chk gpg.format)"; then
    msg --highlight=return "gpg.format is already configured: <b><hl>${config}</b></hl>"
    if ! msg::confirm -y 'do you want to reconfigure gpg.format?'; then
      signing_format="$config"
      msg --highlight=complete 'signing format is configured!'
      return 0
    fi
  fi

  PS3='Select signing format: '
  select format in gpg ssh; do
    if [[ -z "$format" ]]; then
      log::error 'invalid selection'
      continue
    fi
    signing_format="$format"
    break
  done

  case "$signing_format" in
    gpg) abort "unsupported format: ${signing_format}" ;;
    ssh) _git_config_set gpg.format "$signing_format" ;;
  esac

  msg --highlight=complete 'signing format is configured!'
}

configure_signing_key() {
  local config keys set_method

  msg 'configuring signing key.'

  if config="$(_git_config_chk user.signingkey)"; then
    msg --highlight=return "user.signingkey is already configured: <b><hl>${config}</b></hl>"
    if ! msg::confirm -y 'do you want to reconfigure user.signingkey?'; then
      SIGNING_KEY="$config"
      msg --highlight=complete 'signing key is configured!'
      return 0
    fi
  fi

  PS3='Select a method to configure the SSH signing key: '
  local method
  select method in \
    'From ssh-agent' \
    'Enter path to a public key file' \
    'Enter value manually'
  do
    if [[ -z "$method" ]]; then
      log::error 'invalid selection'
      continue
    fi
    # from ssh-agent
    if [[ "${REPLY}" -eq 1 ]]; then
      if ! util::chk -c 'ssh-add'; then
        log::error 'ssh-agent is not available'
        continue
      else
        if ! keys="$(ssh-add -L 2>&1)"; then
          log::error "$keys"
          continue
        fi
      fi
    fi
    set_method="$REPLY"
    break
  done

  case "$set_method" in
    1) # from ssh-agent
      local key lines
      mapfile -t lines <<<"$keys"
      PS3='Which SSH signing key do you want to configure? '
      select key in "${lines[@]}"; do
        if [[ -z "$key" ]]; then
          echo 'invalid selection'
          continue
        fi
        SIGNING_KEY="$key"
        break
      done
      ;;
    2) # public key file path
      SIGNING_KEY="$(msg::read 'public key path:')"
      SIGNING_KEY="${SIGNING_KEY/#\~/$HOME}"
      [[ ! -f "$SIGNING_KEY" ]] && abort 'public key not found'
      ;;
    3) # manual
      SIGNING_KEY="$(msg::read 'enter signing key:')"
      [[ -z "$SIGNING_KEY" ]] && abort 'no signing key selected'
      ;;
  esac

  _git_config_set user.signingkey "$SIGNING_KEY"
  msg --highlight=complete 'signing key is configured!'
}

configure_allowed_signers_file() {
  local config asf
  local skip=false
  local skip_set_allowed_signers_file_path=false

  if msg::confirm -y 'setup an allowed_signer file for verification?'; then
    if config="$(_git_config_chk gpg.ssh.allowedSignersFile)"; then
      msg --highlight=return "gpg.ssh.allowedSignersFile is already configured: <b><hl>${config}</b></hl>"
      if ! msg::confirm -y 'do you want to reconfigure gpg.ssh.allowedSignersFile?'; then
        skip_set_allowed_signers_file_path=true
        asf="$config"
      fi
    fi
  else
    skip=true
  fi

  if [[ "$skip" == 'true' ]]; then
    msg --highlight=warn 'allowed signers configuration skipped.'
    return 0
  fi

  if [[ "$skip_set_allowed_signers_file_path" != 'true' ]]; then
    asf="$(msg::read "enter allowedSignersFile path (default: ~/.ssh/allowed_signers):")"
    asf="${asf/#\~/$HOME}"
    [[ -z "${asf:-}" ]] && asf="${HOME}/.ssh/allowed_signers"
    _git_config_set 'gpg.ssh.allowedSignersFile' "$asf"
    msg --highlight=tip 'allowed_signers lines look like: you@example.com <publickey>'
  fi

  if msg::confirm -y 'add yourself to allowed_signers?'; then
    if ! config="$(_git_config_chk 'user.email')"; then
      log::error 'user.email is not configured'
      msg --highlight=warn 'allowed signers configuration skipped.'
      return 0
    else
      if grep "$config" "$asf" >/dev/null 2>&1; then
        msg --highlight=return "your email is already configured: <b><hl>${config}</b></hl>"
      else
        echo "${config} ${SIGNING_KEY}" >>"$asf"
        msg::notice --configured "${config} ${SIGNING_KEY}"
      fi
    fi
  fi
  msg --highlight=complete 'allowed_signers is configured!'
}

configure_automatic_commit_signing() {
  local config

  msg 'configuring automatic commit signing.'

  if ! config="$(_git_config_chk commit.gpgsign)" || [[ "$config" != 'true' ]]; then
    msg::confirm -y 'automatically sign commits?' && _git_config_set commit.gpgsign true
  else
    msg --highlight=return 'automatic commit signing is already enabled.'
  fi
  msg --highlight=complete 'automatic commit signing is configured!'
}

util::chk -c git
msg 'starting git commit signing configuration.'
configure_signing_format
configure_signing_key
configure_allowed_signers_file
configure_automatic_commit_signing
msg::marker --complete 'git commit signing configured:)'
