# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Dockerfile - pacforge Arch package build container
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

FROM docker.io/archlinux/archlinux:base-devel

# Update repos and install the necessary packages missing on the
# base-devel image
RUN pacman -Syu --needed --noconfirm git

COPY makepkg.conf /etc/makepkg.conf

RUN useradd -m builder && \
        echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder && \
        chmod 0440 /etc/sudoers.d/builder

COPY makepkg-autobuild.sh /usr/local/bin/makepkg-autobuild.sh
RUN chmod +x /usr/local/bin/makepkg-autobuild.sh

RUN touch /etc/makepkg-autobuild-enable

RUN mkdir -p /workdir && chown builder:builder /workdir

USER builder
WORKDIR /workdir
VOLUME ["/workdir"]

ENTRYPOINT ["/usr/local/bin/makepkg-autobuild.sh"]
