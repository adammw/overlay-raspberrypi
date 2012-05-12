Chromium OS for Raspberry Pi
============================

Toolchain setup:
----------------

You only need to do this once (unless you nuke your chroot). To build/install the toolchain, we must be root. To become root, type:

sudo -i

Once you're root, build the toolchain by typing:

USE="-thumb -hardened hardfp" FEATURES="splitdebug" crossdev -S -t armv6j-cros-linux-gnueabi --ex-gdb

This might take some time, so go get a coffee.

Board setup:
------------

Once again, you only need to run this once (unless you nuke the chroot):

./setup_board --board=raspberrypi

If you want to re-create the board root, run:

./setup_board --board=raspberrypi --force

You'll probably want to set the "backdoor" password for a development image to let yourself into a shell when the UI isn't working, to do that, use the following command:

./set_shared_user_password

Once prompted, enter a password, then press enter. As above, you only need to do this once.

Building an image:
------------------

Before we can build an image, we need to build all the required packages. Enter the following command to build those (and pray everything compiles):

./build_packages  --board=raspberrypi --withdev --nowithdebug --nousepkg --nowithautotest

This will take even longer than building the toolchain took. Go get several coffees, and maybe read a book.

Once all the packages have been successfully built, we can build a USB image by running the following command:

./build_image dev --board=raspberrypi --noenable_rootfs_verification
