Chromium OS for Raspberry Pi
============================

Get the code:
-------------

First, you'll need to download the Chromium OS source code. To learn do so, and also how to setup your environment, check out this link: http://www.chromium.org/chromium-os/developer-guide

Once you've downloaded the code and you've reached the "4.3 Select a board" step, continue below.

Add the overlay:
----------------

To build for the Raspberry Pi, you'll need to use the raspberrypi overlay provided by this repo. Until this is merged upstream into the Chromium OS project, you'll have to copy it manually across.

Find the folder named "overlays" in the "src" folder of the code you checked out. You'll see a number of folders with names starting "overlay-". Place the overlay-raspberrypi folder in this folder alongside the other overlays.

Toolchain setup:
----------------

For this step and all following steps you MUST be inside the CrOS chroot. Refer to developer guide section 4.2 if you're not sure how to do this. You only need to do this once (unless you nuke your chroot). To build/install the toolchain, we must be root. To become root, type:

<pre>
sudo -i
</pre>

Once you're root, build the toolchain by typing:

<pre>
USE="-thumb -hardened hardfp" FEATURES="splitdebug" crossdev -S -t armv6j-cros-linux-gnueabi --ex-gdb
</pre>

This might take some time, so go get a coffee.

Board setup:
------------

Once again, you only need to run this once (unless you nuke the chroot):

<pre>
./setup_board --board=raspberrypi
</pre>

If you want to re-create the board root, run:

<pre>
./setup_board --board=raspberrypi --force
</pre>

You'll probably want to set the "backdoor" password for a development image to let yourself into a shell when the UI isn't working, to do that, use the following command:

<pre>
./set_shared_user_password
</pre>

Once prompted, enter a password, then press enter. As above, you only need to do this once.

Building an image:
------------------

Before we can build an image, we need to build all the required packages. Enter the following command to build those (and pray everything compiles):

<pre>
./build_packages  --board=raspberrypi --withdev --nowithdebug --nousepkg --nowithautotest
</pre>

This will take even longer than building the toolchain took. Go get several coffees, and maybe read a book.

Once all the packages have been successfully built, we can build a USB image by running the following command:

<pre>
./build_image dev --board=raspberrypi --noenable_rootfs_verification
</pre>
