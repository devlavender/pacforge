#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# makepkg-autobuild.sh - unattended PKGBUILD dependency install + build
#
# Installs a PKGBUILD's dependencies via pacman, unattended, then runs
# makepkg. POSIX sh only.
#
# THIS FILE IS PART OF:
# pacforge - podman-compatible Arch package build container
#
# COPYRIGHT NOTICE:
#
# Copyright (C) 2026 Agatha Isabelle Moreira <code AT agatha PERIOD dev>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the
# GNU Affero General Public License along with this program.  If not,
# see <https://www.gnu.org/licenses/agpl-3.0.txt>.
#
# A copy of the license is also provided in the file named LICENSE
# distributed with the source code.

set -eu

BUILD="PKGBUILD"
CONF="makepkg.conf"
PACMAN=""

# is_archbuild_container - guard against running on a stray host system.
#
# Succeeds only if:
#   1. /etc/os-release reports ID=arch
#   2. /etc/makepkg-autobuild-enable exists (dropped in at image-build
#      time, on purpose, so this never fires on the host by accident)
#
# Prints an error to stderr and returns non-zero otherwise.
is_archbuild_container()
{
        if [ ! -f /etc/os-release ]; then
                printf 'error: /etc/os-release not found; cannot verify distribution\n' >&2
                return 1
        fi

        # shellcheck disable=SC1091
        . /etc/os-release

        if [ "${ID:-}" != "arch" ]; then
                printf 'error: not running on Arch Linux (ID=%s)\n' "${ID:-unknown}" >&2
                return 1
        fi

        if [ ! -f /etc/makepkg-autobuild-enable ]; then
                printf 'error: /etc/makepkg-autobuild-enable not found; refusing to run outside the intended container\n' >&2
                return 1
        fi

        return 0
}

# check_build_exists - make sure there is a PKGBUILD to work with.
check_build_exists()
{
        if [ ! -f "${BUILD}" ]; then
                printf 'error: %s not found in current directory\n' "${BUILD}" >&2
                return 1
        fi

        return 0
}

# determine_pacman_cmd - decide how pacman should be invoked so the
# whole run stays non-interactive. Sets the global PACMAN variable.
# "sudo -n" fails instead of prompting for a password when not root.
determine_pacman_cmd()
{
        if [ "$(id -u)" -eq 0 ]; then
                PACMAN="pacman"
        else
                PACMAN="sudo pacman"
        fi
}

# extract_deps - print the raw, unparsed contents of depends()/
# makedepends() arrays from ${BUILD}, one array-content chunk per
# match, handling the "+=" append form and multi-line arrays.
# Comments are stripped first.
extract_deps()
{
        awk '
        BEGIN { collecting = 0 }
        {
                line = $0
                sub(/#.*$/, "", line)
                if (!collecting) {
                        if (match(line, /^[[:space:]]*(depends|makedepends)[[:space:]]*\+?=[[:space:]]*\(/)) {
                                collecting = 1
                                sub(/^[^(]*\(/, "", line)
                        } else {
                                next
                        }
                }
                if (collecting) {
                        pos = index(line, ")")
                        if (pos > 0) {
                                print substr(line, 1, pos - 1)
                                collecting = 0
                        } else {
                                print line
                        }
                }
        }
        ' "${BUILD}"
}

# parse_dependencies - turn extract_deps output into one bare package
# name per line: strip quotes, split on whitespace, drop version
# constraints (>=, <=, =, >, <), drop blank lines, de-duplicate.
parse_dependencies()
{
        extract_deps \
                | tr -d '"\047' \
                | tr '\t' ' ' \
                | tr ' ' '\n' \
                | sed -e 's/[<>=].*$//' \
                | sed -e '/^[[:space:]]*$/d' \
                | sort -u
}

# install_dependencies - install every parsed dependency one at a
# time via ${PACMAN}, fully unattended.
install_dependencies()
{
        deps="$(parse_dependencies)"

        if [ -z "${deps}" ]; then
                printf 'no dependencies found in %s\n' "${BUILD}"
                return 0
        fi

        if [ -n "${deps}" ]; then
                printf 'installing dependencies: \n%s\n' "${deps}"
                # shellcheck disable=SC2086
                ${PACMAN} -S --needed --noconfirm --noprogressbar ${deps}
        fi
}

# run_makepkg - invoke makepkg, passing the current directory as its
# first argument if ${CONF} exists, otherwise no extra argument.
# All arguments given to this script are always forwarded unchanged.
run_makepkg()
{
        if [ -f "${CONF}" ]; then
                exec makepkg --config "${CONF}" "${@}"
        else
                exec makepkg "${@}"
        fi
}

main()
{
        is_archbuild_container
        check_build_exists
        determine_pacman_cmd
        install_dependencies
        run_makepkg "${@}"
}

main "${@}"
