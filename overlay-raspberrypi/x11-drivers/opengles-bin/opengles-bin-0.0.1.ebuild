# Copyright (c) 2010 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=2

inherit cros-binary

DESCRIPTION="Binary OpenGL|ES libraries for Raspberry Pi"
SLOT="0"
KEYWORDS="arm"
IUSE="hardfp"

DEPEND=""
RDEPEND="x11-drivers/opengles-headers
	!x11-drivers/opengles"

S=${WORKDIR}

src_unpack() {
        if use hardfp; then
		CROS_BINARY_URI="http://distribution.hexxeh.net/distfiles/raspberrypi-opengles-bin-hardfp-0.0.1.tbz2"
		CROS_BINARY_SUM="78dd05358746f5137c572b63417bfc30c24a0875"
	else
		CROS_BINARY_URI="http://distribution.hexxeh.net/distfiles/raspberrypi-opengles-bin-softfp-0.0.1.tbz2"
		CROS_BINARY_SUM="68e6e063e45700913eaebb1afec24fa4a5e0cf6a"
	fi

        cros-binary_src_unpack

        local pkg=${CROS_BINARY_URI##*/}
        ln -s "${CROS_BINARY_STORE_DIR}/${pkg}"
        unpack ./${pkg}
}

src_install() {
	insinto /usr/lib
	newins libEGL.so libEGL.so.1	  	|| die
	fperms 0755 /usr/lib/libEGL.so.1			|| die
	dosym libEGL.so.1 /usr/lib/libEGL.so			|| die

	newins libGLESv2.so libGLESv2.so.2	  	|| die
	fperms 0755 /usr/lib/libGLESv2.so.2			|| die
	dosym libGLESv2.so.2 /usr/lib/libGLESv2.so		|| die

	newins libbcm_host.so libbcm_host.so	  	|| die
	fperms 0755 /usr/lib/libbcm_host.so			|| die

	newins libvchiq_arm.so libvchiq_arm.so	  	|| die
	fperms 0755 /usr/lib/libvchiq_arm.so			|| die

	newins libvcos.so libvcos.so	  	|| die
	fperms 0755 /usr/lib/libvcos.so			|| die

}
