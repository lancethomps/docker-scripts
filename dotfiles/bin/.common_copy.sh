#!/usr/bin/env bash
################################################################### SETUP ########################################################################
shopt -s expand_aliases
set -o errtrace
##################################################################################################################################################

if ! command -v gsed >/dev/null 2>&1; then
  if test "$(uname)" = "Darwin"; then
    echo "gsed not found, running: brew install gsed"
    brew install gsed
  else
    alias gsed='sed'
  fi
fi

function check_command() {
  if command -v "$@" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}
function check_required_params() {
  if ! check_required_params_without_exit "$@"; then
    exit_fatal_with_usage "Required parameters are missing"
  fi
  return 0
}
function check_required_params_without_exit() {
  local param return_code=0
  for param in "$@"; do
    if test -z "${!param-}"; then
      log_fatal "Parameter '${param}' is required but no value is defined"
      return_code=1
    fi
  done
  return "$return_code"
}
function confirm() {
  local response=""
  read -r -p "${1:-Are you sure?}"$'\n'"[Y/n]> " response
  case "$response" in
    [yY][eE][sS] | [yY] | "") true ;;
    [nN][oO] | [nN]) false ;;
    *)
      echo "Incorrect value entered... Try again."
      confirm "$@"
      ;;
  esac
}
function is_auto_confirm() {
  check_true "${auto_confirm-}"
}
function confirm_with_auto() {
  if is_auto_confirm; then
    log_stderr "AUTO CONFIRMED: ${1-}"
    return 0
  fi
  confirm "$@"
}

function log_debug_or_verbose() {
  if check_debug_or_verbose; then
    log_stderr "$@"
  fi
  return 0
}
function log_verbose() {
  if check_verbose; then
    log_stderr "$@"
  fi
  return 0
}
function check_verbose() {
  check_true "${verbose-}"
}
function check_debug() {
  check_true "${debug_mode-}"
}
function check_debug_or_verbose() {
  check_verbose || check_debug
}
function exit_if_debug() {
  if check_debug; then
    exit 0
  fi

  return 0
}
function check_not_debug() {
  check_true "${debug_mode-}" && return 1 || return 0
}
function run_if_not_debug() {
  if check_debug; then
    get_args_quoted "$@" >&2
    return 0
  fi
  "$@"
}
function check_true() {
  if test -z "${1-}"; then
    return 1
  fi
  local val="${1,,}"
  test "${val}" = "true" && return 0 || test "${val}" = "1" && return 0 || test "${val}" = "yes" && return 0 || test "${val}" = "y" && return 0 || return 1
}
function check_not_true() {
  if check_true "$@"; then
    return 1
  else
    return 0
  fi
}
function check_false() {
  if test -z "${1-}"; then
    return 1
  fi
  local val="${1,,}"
  test "${val}" = "false" && return 0 || test "${val}" = "0" && return 0 || test "${val}" = "no" && return 0 || test "${val}" = "n" && return 0 || return 1
}
function check_not_false() {
  if check_false "$@"; then
    return 1
  else
    return 0
  fi
}
function repeat_char() {
  head -c "$2" </dev/zero | tr '\0' "$1"
}
function get_sep_cols() {
  local sep_cols=160 term_cols
  if check_command get_terminal_columns; then
    term_cols="$(get_terminal_columns)"
    if test -n "$term_cols"; then
      sep_cols="$term_cols"
    fi
  fi
  if test -n "${1-}"; then
    sep_cols="$((sep_cols / $1))"
  fi
  echo -n "$sep_cols"
}
function log_sep() {
  if test -z "${TERMINAL_SEP-}"; then
    local rep_count
    rep_count="$(get_sep_cols 2)"
    TERMINAL_SEP="$(repeat_char '-' "$rep_count")"
    export TERMINAL_SEP
  fi
  echo "$TERMINAL_SEP"
}
# shellcheck disable=SC2120,SC2005
function log_sep_large() {
  if test -n "${1-}"; then
    echo "$(repeat_char "${1}" "$(get_sep_cols)")"
    return 0
  fi

  if test -z "${TERMINAL_LARGE_SEP-}"; then
    TERMINAL_LARGE_SEP="$(repeat_char '#' "$(get_sep_cols)")"
    export TERMINAL_LARGE_SEP
  fi
  echo "$TERMINAL_LARGE_SEP"
}
function log_section() {
  local full_width title_width sep_width sep ending=""

  full_width="$(get_sep_cols)"
  # shellcheck disable=SC2000
  title_width="$(echo -n "$@" | python3 -c "import re;import sys;sys.stdout.write(re.sub(r'\\x1B\\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]', '', sys.stdin.read()))" | wc -c)"
  sep_width="$(bc -e "((${full_width} - ${title_width}) / 2) - 1")"
  sep="$(repeat_char '#' "$sep_width")"

  if test "$((title_width + 2 + sep_width + sep_width))" -lt "${full_width}"; then
    ending="#"
  fi

  {
    log_sep_large
    log_stderr "$(printf '%s %s %s\n' "$sep" "$*" "${sep}${ending}")"
    log_sep_large
  } >&2
}
function log_spaced() {
  echo
  echo "$@"
}
function log_with_sep_around() {
  log_sep
  echo "$@"
  log_sep
}
function log_with_title_sep() {
  echo
  log_with_title_sep_no_leading_blank_line "$@"
}
function log_with_title_sep_around() {
  log_with_title_sep "$1" >&2
  shift
  log_stderr "$@"
  log_sep >&2
}
function log_with_title_sep_no_leading_blank_line() {
  echo "$@"
  log_sep
}
function log_and_run() {
  log_with_title_sep_no_leading_blank_line "$(get_args_quoted "$@")" >&2
  "$@"
}
function log_and_run_spaced() {
  log_with_title_sep "$(get_args_quoted "$@")" >&2
  "$@"
}
function log_and_run_no_sep() {
  get_args_quoted "$@" >&2
  "$@"
}
function log_and_run_surround() {
  local exit_code

  set +o errexit
  log_and_run "$@"
  exit_code=$?
  set -o errexit

  log_sep

  return "$exit_code"
}
function log_and_run_spaced_surround() {
  local exit_code

  set +o errexit
  log_and_run_spaced "$@"
  exit_code=$?
  set -o errexit

  log_sep >&2

  return "$exit_code"
}
function log_verbose_and_run() {
  if check_verbose; then
    log_and_run "$@"
  else
    "$@"
  fi
}
function log_verbose_and_run_spaced() {
  if check_verbose; then
    log_and_run_spaced "$@"
  else
    "$@"
  fi
}
function log_verbose_and_run_spaced_surround() {
  if check_verbose; then
    log_and_run_spaced_surround "$@"
  else
    "$@"
  fi
}
function log_verbose_and_run_surround() {
  if check_verbose; then
    log_and_run_surround "$@"
  else
    "$@"
  fi
}
function log_verbose_and_run_no_sep() {
  if check_verbose; then
    log_and_run_no_sep "$@"
  else
    "$@"
  fi
}
function log_and_run_if_not_debug() {
  if check_debug; then
    get_args_quoted "$@" >&2
    return 0
  fi
  log_with_title_sep_no_leading_blank_line "$(get_args_quoted "$@")" >&2
  "$@"
}
function log_and_run_spaced_surround_if_not_debug() {
  if check_debug; then
    get_args_quoted "$@" >&2
    return 0
  fi
  log_and_run_spaced_surround "$@"
}
function log_stderr() {
  echo "$@" >&2
}
function log_debug() {
  log_stderr "DEBUG" "$@"
}
function log_warn() {
  log_stderr "WARNING" "$@"
}
function log_error() {
  log_stderr "ERROR" "$@"
}
function log_fatal() {
  log_stderr "FATAL" "$@"
}
function exit_fatal_with_usage() {
  if command -v _usage >/dev/null 2>&1; then
    log_with_title_sep USAGE
    _usage
    log_sep
  fi
  exit_fatal "$@"
}
function exit_fatal() {
  local exit_code="${1-}"
  if test "$#" -le 1; then
    exit_code=1
  else
    shift
  fi
  log_fatal "$@"
  exit "$exit_code"
}
function return_fatal() {
  local exit_code="${1-}"
  if test "$#" -le 1; then
    exit_code=1
  else
    shift
  fi
  log_fatal "$@"
  return "$exit_code"
}

# shellcheck disable=SC2120
function should_use_pager() {
  if test -n "${use_pager-}"; then
    if check_true "${use_pager-}"; then
      return 0
    else
      return 1
    fi
  fi
  local arg
  for arg in "$@"; do
    if test "${arg}" = '--no-pager'; then
      return 1
    elif test "${arg}" = '--pager'; then
      return 0
    fi
  done
  if test -z "${PAGER-}"; then
    return 1
  elif ! test -t 1; then
    return 1
  fi
  return 0
}
function get_args_quoted() {
  if test -z "${1-}"; then
    return 1
  fi
  local var all_args=''
  for var in "$@"; do
    if [[ $var =~ ^[\-_=/~:.a-zA-Z0-9]+$ ]] || [[ $var =~ ^[a-zA-Z0-9_]+= ]]; then
      if test -z "${all_args-}"; then
        all_args="${var}"
      else
        all_args="$all_args $var"
      fi
    elif [[ $var != *"'"* ]] && [[ $var == *'"'* ]]; then
      if test -z "${all_args}"; then
        all_args="'$var'"
      else
        all_args="$all_args '$var'"
      fi
    else
      var="${var//\\/\\\\}"
      var="${var//\"/\\\"}"
      if test -n "${ESCAPE_VALS-}"; then
        var="$(echo "${var}" | sed -E "s/([$ESCAPE_VALS])/\\\\\1/g")"
      fi
      if test -z "${all_args}"; then
        all_args="\"$var\""
      else
        all_args="$all_args \"$var\""
      fi
    fi
  done
  echo "${all_args}"
}
function ask_user_for_input() {
  local response allow_empty
  allow_empty="${2:-false}"
  read -r -p "${1:-Please input a value.}"$'\n'"> " response
  if test -z "${response-}" && test "${allow_empty-}" != "true"; then
    echo "No value entered, please try again."
    ask_user_for_input "$@"
    return $?
  fi
  echo "${response-}"
}
function is_arg_present() {
  local expected_arg arg

  expected_arg="$1"
  shift

  for arg in "$@"; do
    if test "${arg}" = "${expected_arg}"; then
      return 0
    fi
  done

  return 1
}

function get_terminal_columns() {
  if test -z "${COLUMNS-}"; then
    COLUMNS="$(stty -a 2>/dev/null | head -1 | command grep -ioE 'columns [0-9]+' | sed -E 's/[^0-9]//g')"
    if test -z "${COLUMNS-}"; then
      COLUMNS="$(stty -a 2>/dev/null | head -1 | command grep -ioE '[0-9]+ columns' | sed -E 's/[^0-9]//g')"
    fi
    export COLUMNS
  fi
  echo -n "${COLUMNS}"
}

function longest_line_length() {
  local str
  if ! test -t 0; then
    str="$(cat)"
  else
    for val in "${@}"; do
      str="${str-}${val}"$'\n'
    done
  fi
  echo "${str-}" | awk 'length > max_length { max_length = length; longest_line = $0 } END { print max_length }'
}
function join_by() {
  local delim="${1//\&/\\&}"
  shift

  echo -n "$1"
  shift
  printf "%s" "${@/#/$delim}"
}
function join_by_with_end() {
  join_by "$@"
  echo
}
function join_by_newline() {
  join_by $'\n' "$@"
}
function join_by_newline_with_end() {
  join_by_newline "$@"
  echo
}
function join_by_regex_or() {
  echo "($(join_by '|' "$@"))"
}

function url_decode_py() {
  python -c '
import sys
try:
  import urllib.parse as urllib_parse
except:
  import urllib as urllib_parse

print(urllib_parse.unquote_plus(sys.argv[1]))
' "$@"
}

function url_encode_py() {
  python -c '
import sys
try:
  import urllib.parse as urllib_parse
except:
  import urllib as urllib_parse

print(urllib_parse.quote_plus(sys.argv[1], safe=(sys.argv[2] if len(sys.argv) > 2 else "/")))
' "$@"
}

function repeat_run() {
  local times="$1" idx
  shift

  # shellcheck disable=SC2034
  for idx in $(seq "$times"); do
    "$@"
  done
}

function git_base_dir() {
  if command -v git-base-dir >/dev/null 2>&1; then
    git base-dir
  else
    git rev-parse --show-toplevel
  fi
}

function git_in_repo() {
  if command -v git-in-repo >/dev/null 2>&1; then
    git in-repo
  else
    test -d .git || git rev-parse --git-dir >/dev/null 2>&1
  fi
}

function cd_to_git_base_dir() {
  cd "$(git_base_dir)" || exit_fatal "Could not cd to git base-dir: $(git_base_dir)"
}

function cd_to_git_base_dir_if_needed() {
  if git_in_repo && check_true "${cd_to_git_base_dir-}"; then
    cd_to_git_base_dir
  fi

  return 0
}
