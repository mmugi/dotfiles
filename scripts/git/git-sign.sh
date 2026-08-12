#!/usr/bin/env bash

set -ueo pipefail

trap 'echo; echo "Interrupted."; exit 130' INT

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import util msg theme log

theme::load
msg::init

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
  msg::changed "configured: ${key}: ${value}"
}

configure_signing_format() {
  msg::header 'signing format configuration'

  local config signing_format

  if config="$(_git_config_chk gpg.format)"; then
    msg "gpg.format is already configured: <hl>${config}</hl>"
    msg::skipped 'signing format configuration skipped.'
    newline
    return 0
  fi

  signing_format="$(msg::select --ps='select signing format: ' gpg ssh)"

  case "$signing_format" in
    gpg)
      msg::error "unsupported format: ${signing_format}"
      exit 1
      ;;
    ssh)
      _git_config_set gpg.format "$signing_format"
      ;;
  esac

  msg::ok 'signing format configured!'
  newline
}

_validation_signingkey() {
  local pubkey="$1"
  local content type result

  if [[ -f "$pubkey" ]]; then
    content="$(<"$pubkey")"
    type='file'
  else
    content="$pubkey"
    type='notfile'
  fi

  if result="$(ssh-keygen -vlf /dev/stdin <<<"$content" 2>/dev/null)"; then
    msg::box --no-prompt -- "$result"
    SIGNING_KEY_TYPE="$type"
    return 0
  else
    msg::warning 'invalid signing key:('
    return 1
  fi
}

configure_signing_key() {
  msg::header 'signing key configuration'

  util::chk -c ssh-keygen

  local config content pubkey

  if config="$(_git_config_chk user.signingkey)"; then
    msg "user.signingkey is already configured: <hl>${config}</hl>"

    if _validation_signingkey "$config"; then
      SIGNING_KEY="$config"
      msg::skipped 'signing key configuration skipped.'
      newline
      return 0
    fi
  fi

  local method
  local -a methods=(
    'enter path to a public key file'
    'enter value manually'
  )

  if util::chk -c 'ssh-add'; then
    methods+=( 'from ssh-agent' )
  fi

  while true; do
    method="$(
      msg::select \
        --ps='select a method to configure the SSH signing key: ' \
        "${methods[@]}"
    )"

    case "$method" in
      'from ssh-agent')
        local keys lines

        if ! keys="$(ssh-add -L 2>&1)"; then
          msg::warning "$keys"
          continue
        fi

        mapfile -t lines <<<"$keys"
        SIGNING_KEY="$(msg::select \
          --ps='which SSH public key do you want to configure? ' \
          "${lines[@]}"
        )"

        if ! _validation_signingkey "$SIGNING_KEY"; then
          continue
        fi
        ;;

      'enter path to a public key file')
        while true; do
          SIGNING_KEY="$(msg::read -e -i "${HOME}/" -- 'enter the path to the public key: ')"
          SIGNING_KEY="${SIGNING_KEY## }"
          SIGNING_KEY="${SIGNING_KEY%% }"
          SIGNING_KEY="${SIGNING_KEY/#\~/${HOME}}"

          if [[ -z "$SIGNING_KEY" ]]; then
            continue
          elif [[ ! -f "$SIGNING_KEY" ]]; then
            msg::warning "public key file not found: ${SIGNING_KEY}"
            continue
          elif ! _validation_signingkey "$SIGNING_KEY"; then
            continue
          else
            break
          fi
        done
        ;;

      'enter value manually')
        while true; do
          SIGNING_KEY="$(msg::read -- 'enter the public key: ')"
          SIGNING_KEY="${SIGNING_KEY## }"
          SIGNING_KEY="${SIGNING_KEY%% }"
          SIGNING_KEY="${SIGNING_KEY/#\~/${HOME}}"

          if [[ -z "$SIGNING_KEY" ]]; then
            continue
          elif ! _validation_signingkey "$SIGNING_KEY"; then
            continue
          else
            break
          fi
        done
        ;;
    esac
    break
  done

  _git_config_set user.signingkey "$SIGNING_KEY"

  msg::ok 'signing key configured!'
  newline
}

configure_allowed_signers() {
  msg::header 'allowed signers configuration'

  local config allowed_signers_file

  if config="$(_git_config_chk gpg.ssh.allowedSignersFile)"; then
    msg "gpg.ssh.allowedSignersFile is already configured: <hl>${config}</hl>"

    if [[ -f "$config" ]]; then
      allowed_signers_file="$config"
    else
      msg::warning "allowed signers file not found: ${config:-}"
    fi
  fi

  [[ -z "${allowed_signers_file:-}" ]] && while true; do
    allowed_signers_file="$(
      msg::read -e \
        -- "enter the allowed_signers file (default: ~/.ssh/allowed_signers): "
    )"
    allowed_signers_file="${allowed_signers_file## }"
    allowed_signers_file="${allowed_signers_file%% }"
    allowed_signers_file="${allowed_signers_file/#\~/${HOME}}"

    if [[ -z "${allowed_signers_file:-}" ]]; then
      allowed_signers_file="${HOME}/.ssh/allowed_signers"
    fi

    if [[ -f "$allowed_signers_file" ]]; then
      _git_config_set 'gpg.ssh.allowedSignersFile' "$allowed_signers_file"
      break
    else
      msg::warning "allowed signers file not found: ${allowed_signers_file}"
      allowed_signers_file=
      continue
    fi
  done

  local principal key_type base64_key line

  if ! principal="$(_git_config_chk 'user.email')"; then
    msg::error 'user.email is not configured'
    exit 1
  fi

  case "$SIGNING_KEY_TYPE" in
    file)    read -r key_type base64_key _ <"$SIGNING_KEY" ;;
    notfile) read -r key_type base64_key _ <<<"$SIGNING_KEY" ;;
    *) logger --fatal "invalid SIGNING_KEY_TYPE: ${SIGNING_KEY_TYPE:-notset}" ;;
  esac

  line="$(printf '%s %s %s' "$principal" "$key_type" "$base64_key")"

  if grep "$line" "$allowed_signers_file" >/dev/null 2>&1; then
    msg "already registered in the allowed signers file: <hl>${line}</hl>"
    msg::skipped 'allowed signers configuration skipped.'
    newline
    return 0
  fi

  if msg::confirm --yes-no 'add yourself to allowed signers?'; then
    printf '%s\n' "$line" >>"$allowed_signers_file"
    msg::changed "added to allowed signers: ${line} >> ${allowed_signers_file}"
    msg::ok 'allowed signers configured!'
  else
    msg::skipped 'addition of entry to allowed signers skipped.'
  fi

  newline
}

configure_commit_signing() {
  msg::header 'commit signing configuration'

  local config

  if config="$(_git_config_chk commit.gpgsign)" && [[ "$config" == 'true' ]]; then
    msg 'commit signing is already enabled.'
    msg::skipped 'commit signing configuration skipped.'
  else
    if msg::confirm --yes-no 'sign commits by default?'; then
      _git_config_set commit.gpgsign true
      msg::ok 'commit signing configured!'
    else
      msg::skipped 'commit signing configuration skipped.'
    fi
  fi

  newline
}

util::chk -c git
newline

configure_signing_format
configure_signing_key
configure_allowed_signers
configure_commit_signing
msg::box --prompt='🐈️' --base-style='success' -- 'GIT SIGNING CONFIGURED'
