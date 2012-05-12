# Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=4
EGIT_PROJECT="Hexxeh/raspberrypi-kernel"
EGIT_REPO_URI="git://github.com/${EGIT_PROJECT}.git"
EGIT_BRANCH="rpi-patches"

# To move up to a new commit, you should update this and then bump the
# symlink to a new rev.
EGIT_COMMIT="6e588cb5b2ad6dfcf604ce81f2f2bae15c4797bb"

# This must be inherited *after* EGIT/CROS_WORKON variables defined
inherit git cros-kernel2

DESCRIPTION="Chrome OS Kernel-raspberrypi"
KEYWORDS="amd64 arm x86"

DEPEND="!sys-kernel/chromeos-kernel-next
	!sys-kernel/chromeos-kernel
"
RDEPEND="${DEPEND}"
