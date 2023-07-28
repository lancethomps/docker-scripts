#!/usr/bin/env bash

function _create_wrapped_docker_completion() {
  local cmd_type="$1"
  shift
  eval "_docker_wrapped_${cmd_type}() { _docker_wrapped ${cmd_type} \"\$@\"; }"
  _default_completion -F "_docker_wrapped_${cmd_type}" "$@"
}

function _docker_wrapped() {
  local args=(docker "$1")
  COMP_WORDS=("${args[@]}" "${COMP_WORDS[@]:1}")
  COMP_LINE="${COMP_WORDS[*]}"
  COMP_CWORD="$((COMP_CWORD + 1))"
  _docker
}

_default_completion -F _docker d

_create_wrapped_docker_completion exec \
  d_exec \
  d_exec_bash

_create_wrapped_docker_completion logs \
  d_logs

_create_wrapped_docker_completion rm \
  d_rm

unset _create_wrapped_docker_completion
