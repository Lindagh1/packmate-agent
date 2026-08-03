#!/usr/bin/env bash
# Consistent failure messaging for Packmate workshop scripts.
# shellcheck shell=bash

packmate_fail() {
  printf 'FAIL    %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then
    printf 'DETAIL  %s\n' "$2" >&2
  fi
  if [[ -n "${3:-}" ]]; then
    printf 'ACTION  %s\n' "$3" >&2
  fi
}

packmate_blocked() {
  printf 'BLOCKED %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then
    printf 'DETAIL  %s\n' "$2" >&2
  fi
  if [[ -n "${3:-}" ]]; then
    printf 'ACTION  %s\n' "$3" >&2
  fi
}

packmate_info_action() {
  printf 'INFO    %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf 'ACTION  %s\n' "$2"
  fi
}

packmate_pass() {
  printf 'PASS    %s\n' "$*"
}
