# Copyright (c) 2011 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

# Usage: by default, downloads chromium browser from the build server.
# If CHROME_ORIGIN is set to one of {SERVER_SOURCE, LOCAL_SOURCE, LOCAL_BINARY},
# the build comes from the chromimum source repository (gclient sync),
# build server, locally provided source, or locally provided binary.
# If you are using SERVER_SOURCE, a gclient template file that is in the files
# directory which will be copied automatically during the build and used as
# the .gclient for 'gclient sync'.
# If building from LOCAL_SOURCE or LOCAL_BINARY specifying BUILDTYPE
# will allow you to specify "Debug" or another build type; "Release" is
# the default.
# gclient is expected to be in ~/depot_tools if EGCLIENT is not set
# to gclient path.

EAPI="2"
inherit autotest-deponly binutils-funcs eutils flag-o-matic git multilib toolchain-funcs

DESCRIPTION="Open-source version of Google Chrome web browser"
HOMEPAGE="http://www.chromium.org/"
SRC_URI=""

KEYWORDS="amd64 arm x86"

LICENSE="BSD"
SLOT="0"

IUSE="-asan -aura +build_tests x86 +gold +chrome_remoting chrome_internal chrome_pdf +chrome_debug -chrome_debug_tests 
-chrome_media -clang -component_build +reorder hardfp -pgo -pgo_generate +runhooks +verbose -drm nacl"

# Do not strip the nacl_helper_bootstrap binary because the binutils
# objcopy/strip mangles the ELF program headers.
# TODO(mcgrathr,vapier): This should be removed after portage's prepstrip
# script is changed to use eu-strip instead of objcopy and strip.
STRIP_MASK="*/nacl_helper_bootstrap"

PGO_SUBDIR="pgo"

# Bots in golo.chromium.org have private mirrors that are only accessible
# from within golo.chromium.org. TODO(rcui): Remove this once we've
# converted all bots to GERRIT_SOURCE.
DOMAIN_NAME=$(hostname -d)
if [ "${DOMAIN_NAME}" == "golo.chromium.org" ]; then
	EXTERNAL_URL="svn://svn-mirror.golo.chromium.org/chrome"
	INTERNAL_URL="svn://svn-mirror.golo.chromium.org/chrome-internal"
else
	EXTERNAL_URL="http://src.chromium.org/svn"
	INTERNAL_URL="svn://svn.chromium.org/chrome-internal"
fi
# Portage version without optional portage suffix.
CHROME_VERSION="${PV/_*/}"
[[ ( "${PV}" = "9999" ) || ( -n "${CROS_SVN_COMMIT}" ) ]]
USE_TRUNK=$?

REVISION="/${CHROME_VERSION}"
if [ ${USE_TRUNK} = 0 ]; then
	REVISION=
	if [ -n "${CROS_SVN_COMMIT}" ]; then
		REVISION="@${CROS_SVN_COMMIT}"
	fi
fi

if use chrome_internal; then
	if [ ${USE_TRUNK} = 0 ]; then
		PRIMARY_URL="${EXTERNAL_URL}/trunk/src"
		AUXILIARY_URL="${INTERNAL_URL}/trunk/src-internal"
	else
		PRIMARY_URL="${INTERNAL_URL}/trunk/tools/buildspec/releases"
		AUXILIARY_URL=
	fi
else
	if [ ${USE_TRUNK} = 0 ]; then
		PRIMARY_URL="${EXTERNAL_URL}/trunk/src"
	else
		PRIMARY_URL="${EXTERNAL_URL}/releases"
	fi
	AUXILIARY_URL=
fi

CHROME_SRC="chrome-src"
if use chrome_internal; then
	CHROME_SRC="${CHROME_SRC}-internal"
fi

# CHROME_CACHE_DIR is used for storing output artifacts, and is always a
# regular directory inside the chroot (i.e. it's never mounted in, so it's
# always safe to use cp -al for these artifacts).
if [[ -z ${CHROME_CACHE_DIR} ]] ; then
	CHROME_CACHE_DIR="/var/cache/chromeos-chrome/${CHROME_SRC}"
fi
addwrite "${CHROME_CACHE_DIR}"

# CHROME_DISTDIR is used for storing the source code, if any source code
# needs to be unpacked at build time (e.g. in the SERVER_SOURCE scenario.)
# It will be mounted into the chroot, so it is never safe to use cp -al
# for these files.
if [[ -z ${CHROME_DISTDIR} ]] ; then
	CHROME_DISTDIR="${PORTAGE_ACTUAL_DISTDIR:-${DISTDIR}}/${CHROME_SRC}"
fi
addwrite "${CHROME_DISTDIR}"

# chrome destination directory
CHROME_DIR=/opt/google/chrome
D_CHROME_DIR="${D}/${CHROME_DIR}"
RELEASE_EXTRA_CFLAGS=()

if [ "$ARCH" = "x86" ] || [ "$ARCH" = "amd64" ]; then
	DEFAULT_CHROME_DIR=chromium-rel-linux-chromiumos
	USE_TCMALLOC="linux_use_tcmalloc=1"
elif [ "$ARCH" = "arm" ]; then
	DEFAULT_CHROME_DIR=chromium-rel-arm
	# tcmalloc isn't supported on arm
	USE_TCMALLOC="linux_use_tcmalloc=0"
fi

# For compilation/local chrome
BUILD_TOOL=make
BUILDTYPE="${BUILDTYPE:-Release}"
BOARD="${BOARD:-${SYSROOT##/build/}}"
BUILD_OUT="${BUILD_OUT:-out_${BOARD}}"
# WARNING: We are using a symlink now for the build directory to work around
# command line length limits. This will cause problems if you are doing
# parallel builds of different boards/variants.
# Unsetting BUILD_OUT_SYM will revert this behavior
BUILD_OUT_SYM="c"

CHROME_BASE=${CHROME_BASE:-"http://build.chromium.org/f/chromium/snapshots/${DEFAULT_CHROME_DIR}"}

TEST_FILES=("ffmpeg_tests")
if [ "$ARCH" = "arm" ]; then
	TEST_FILES+=( "omx_video_decode_accelerator_unittest" "ppapi_example_video_decode" )
fi

RDEPEND="${RDEPEND}
	app-arch/bzip2
	>=app-i18n/ibus-1.4.99
	arm? ( virtual/opengles )
	!aura? ( chromeos-base/chromeos-theme )
	chromeos-base/protofiles
	dev-libs/atk
	dev-libs/glib
	dev-libs/nspr
	>=dev-libs/nss-3.12.2
	dev-libs/libxml2
	dev-libs/dbus-glib
	x11-libs/cairo
	drm? ( x11-libs/libxkbcommon )
	x11-libs/libXScrnSaver
	x11-libs/gtk+
	x11-libs/pango
	>=media-libs/alsa-lib-1.0.19
	media-libs/fontconfig
	media-libs/freetype
	virtual/jpeg
	media-libs/libpng
	media-libs/mesa
	media-sound/adhd
	net-misc/wget
	sys-fs/udev
	sys-libs/zlib
	!aura? ( x86? ( !chrome_internal? ( www-plugins/adobe-flash ) ) )
	>=x11-libs/gtk+-2.14.7
	x11-libs/libXScrnSaver
	chrome_remoting? ( x11-libs/libXtst )
	x11-apps/setxkbmap"

DEPEND="${DEPEND}
	${RDEPEND}
	arm? ( x11-drivers/opengles-headers )
	>=dev-util/gperf-3.0.3
	>=dev-util/pkgconfig-0.23
	net-wireless/bluez"

PATCHES=()

AUTOTEST_COMMON="src/chrome/test/chromeos/autotest/files"
AUTOTEST_DEPS="${AUTOTEST_COMMON}/client/deps"
AUTOTEST_DEPS_LIST="chrome_test pyauto_dep"

IUSE="${IUSE} +autotest"

export CHROMIUM_HOME=/usr/$(get_libdir)/chromium-browser

QA_TEXTRELS="*"
QA_EXECSTACK="*"
QA_PRESTRIPPED="*"

use_nacl() {
	! use asan && ! use component_build && ! use drm && use nacl
}

set_build_defines() {
	# General build defines.
	BUILD_DEFINES=(
		"sysroot=$ROOT"
		python_ver=2.6
		"linux_sandbox_path=${CHROME_DIR}/chrome-sandbox"
		"${EXTRA_BUILD_ARGS}"
		"system_libdir=$(get_libdir)"
		"pkg-config=$(tc-getPKG_CONFIG)"
		"use_xi2_mt=2"
	)

	# use_ibus=1 is necessary for supporting i18n text input.
	# Do not remove.
	BUILD_DEFINES+=(
		swig_defines=-DOS_CHROMEOS
		chromeos=1
                use_ibus=1
	)

	if use pgo_generate ; then
		BUILD_DEFINES+=(
			libraries_for_target=-lgcov
		)
		RELEASE_EXTRA_CFLAGS+=(
			-DPGO_GENERATE
			-fprofile-generate
			-fprofile-dir=/tmp/pgo/chrome
			-Wno-error=maybe-uninitialized
		)
	fi

	# Set proper BUILD_DEFINES for the arch
	if [ "$ARCH" = "x86" ]; then
		BUILD_DEFINES+=( target_arch=ia32 enable_smooth_scrolling=1 )
	elif [ "$ARCH" = "arm" ]; then
		BUILD_DEFINES+=( target_arch=arm armv7=1 v8_can_use_unaligned_accesses=true )
		if [ "$(expr match "$ARM_FPU" "vfpv3")" -ne 0 ]; then
			BUILD_DEFINES+=( v8_can_use_vfp_instructions=true )
		fi
		if use chrome_internal; then
			#http://code.google.com/p/chrome-os-partner/issues/detail?id=1142
			BUILD_DEFINES+=( internal_pdf=0 )
		fi
		if use hardfp; then
			BUILD_DEFINES+=( v8_use_arm_eabi_hardfloat=true )
		fi
	elif [ "$ARCH" = "amd64" ]; then
		BUILD_DEFINES+=( target_arch=x64 enable_smooth_scrolling=1 )
	else
		die "Unsupported architecture: ${ARCH}"
	fi

	use_nacl || BUILD_DEFINES+=( disable_nacl=1 )

	use drm && BUILD_DEFINES+=( use_drm=1 )

	# Control inclusion of optional chrome features.
	if use chrome_remoting; then
		BUILD_DEFINES+=( remoting=1 )
	else
		BUILD_DEFINES+=( remoting=0 )
	fi

	if use chrome_internal; then
		#Adding chrome branding specific variables and GYP_DEFINES
		BUILD_DEFINES+=( branding=Chrome buildtype=Official )
		export CHROMIUM_BUILD='_google_Chrome'
		export OFFICIAL_BUILD='1'
		export CHROME_BUILD_TYPE='_official'

		# For internal builds, don't remove webcore debug symbols by default.
		REMOVE_WEBCORE_DEBUG_SYMBOLS=${REMOVE_WEBCORE_DEBUG_SYMBOLS:-0}
	elif use chrome_media; then
		echo "Building Chromium with additional media codecs and containers."
		BUILD_DEFINES+=( ffmpeg_branding=ChromeOS proprietary_codecs=1 )
	fi

	# This saves time and bytes.
	if [ "${REMOVE_WEBCORE_DEBUG_SYMBOLS:-1}" = "1" ]; then
		BUILD_DEFINES+=( remove_webcore_debug_symbols=1 )
	fi

	if use reorder && ! use clang; then
		BUILD_DEFINES+=( "order_text_section=${CHROME_DISTDIR}/${PGO_SUBDIR}/section-ordering-files/orderfile" )
	fi

	if ! use chrome_debug_tests; then
		BUILD_DEFINES+=( strip_tests=1 )
	fi

	if use clang; then
		if [ "$ARCH" = "x86" ] || [ "$ARCH" = "amd64" ]; then
			BUILD_DEFINES+=( clang=1 werror= )
			USE_TCMALLOC="linux_use_tcmalloc=0"

			# The chrome build system will add -m32 for 32bit arches, and
			# clang defaults to 64bit because our cros_sdk is 64bit default.
			export CC="clang" CXX="clang++"
		else
			die "Clang is not yet supported for ${ARCH}"
		fi
	fi

	if use asan; then
		if ! use clang; then
			eerror "Asan requires Clang to run."
			die "Please set USE=\"${USE} clang\" to enable Clang"
		fi
		BUILD_DEFINES+=( asan=1 )
	fi

	if use aura; then
		BUILD_DEFINES+=( use_aura=1 )
	fi

	if use component_build; then
		BUILD_DEFINES+=( component=shared_library )
	fi

	BUILD_DEFINES+=( "${USE_TCMALLOC}" )
	BUILD_DEFINES+=( "use_cras=1" )

	# TODO(davidjames): Pass in all CFLAGS this way, once gyp is smart enough
	# to accept cflags that only apply to the target.
	if use chrome_debug; then
		RELEASE_EXTRA_CFLAGS+=(
			-g
		)
	fi

	if ! use chrome_pdf; then
		BUILD_DEFINES+=( internal_pdf=0 )
	fi

	BUILD_DEFINES+=( "release_extra_cflags='${RELEASE_EXTRA_CFLAGS[*]}'" )

	export GYP_GENERATORS="${BUILD_TOOL}"
	export GYP_DEFINES="${BUILD_DEFINES[@]}"
	export builddir_name="${BUILD_OUT}"
	# Prevents gclient from updating self.
	export DEPOT_TOOLS_UPDATE=0
}

create_gclient_file() {
	local echrome_store_dir=${1}
	local primary_url=${2}
	local auxiliary_url=${3}
	local revision=${4}
	local use_pdf=${5}
	local use_trunk=${6}

	local layout_tests="src/chrome/test/data/layout_tests/LayoutTests"

	local pdf1="\"src/pdf\": None,"
	local pdf2="\"src-pdf\": None,"
	local checkout_point="CHROME_DEPS"

	# Bots in golo.chromium.org have private mirrors that are only accessible
	# from within golo.chromium.org. TODO(rcui): Remove this once we've
	# converted all bots to GERRIT_SOURCE.
	local custom_vars=''
	if [ "${DOMAIN_NAME}" == "golo.chromium.org" ]; then
		custom_vars='
"webkit_trunk": "svn://svn-mirror.golo.chromium.org/webkit-readonly/trunk",
"googlecode_url": "svn://svn-mirror.golo.chromium.org/%s",
"sourceforge_url": "svn://svn-mirror.golo.chromium.org/%(repo)s",'
	fi

	if [ ${use_pdf} = 0 ]; then
		pdf1=
		pdf2=
	fi
	if [ ${use_trunk} = 0 ]; then
		checkout_point="src"
	fi
	echo "solutions = [" >${echrome_store_dir}/.gclient
	cat >>${echrome_store_dir}/.gclient <<EOF
	{"name"        : "${checkout_point}",
	 "url"         : "${primary_url}${revision}",
	 "custom_deps" : {
		"src/chrome/tools/test/reference_build/chrome": None,
		"src/chrome/tools/test/reference_build/chrome_mac": None,
		"src/chrome/tools/test/reference_builds/chrome_linux": None,
		"src/chrome_frame/tools/test/reference_build/chrome": None,
		"src/third_party/WebKit/LayoutTests": None,
		"${layout_tests}/fast/filesystem/workers": None,
		"${layout_tests}/fast/filesystem/resources": None,
		"${layout_tests}/fast/js/resources": None,
		"${layout_tests}/fast/events": None,
		"${layout_tests}/fast/workers": None,
		"${layout_tests}/http/tests/appcache": None,
		"${layout_tests}/http/tests/filesystem": None,
		"${layout_tests}/http/tests/resources": None,
		"${layout_tests}/http/tests/websocket/tests": None,
		"${layout_tests}/http/tests/workers": None,
		"${layout_tests}/http/tests/xmlhttprequest": None,
		"${layout_tests}/media": None,
		"${layout_tests}/platform/chromium/fast/workers": None,
		"${layout_tests}/platform/chromium-cg-mac/fast/events": None,
		"${layout_tests}/platform/chromium-cg-mac/http/tests/workers": None,
		"${layout_tests}/platform/chromium-cg-mac/storage/domstorage": None,
		"${layout_tests}/platform/chromium-win/fast/events": None,
		"${layout_tests}/platform/chromium-win/fast/workers": None,
		"${layout_tests}/platform/chromium-win/http/tests/workers": None,
		"${layout_tests}/platform/chromium-win/storage/domstorage": None,
		"${layout_tests}/storage/domstorage": None,
		$pdf1
		$pdf2
		},
	 "custom_vars": {
		$custom_vars
		},
	},
EOF
	if [ -n "${auxiliary_url}" ]; then
		cat >>${echrome_store_dir}/.gclient <<EOF
  { "name"        : "aux_src",
	"url"         : "${auxiliary_url}${revision}",
  },
EOF
	fi
	if [ ${use_trunk} = 0 ]; then
		cat >>${echrome_store_dir}/.gclient <<EOF
  { "name"        : "cros",
	"url"         : "${primary_url}/tools/cros.DEPS${revision}",
  },
EOF
	fi
	echo "]" >>${echrome_store_dir}/.gclient
}

unpack_chrome() {
	elog "Storing CHROME_VERSION=${CHROME_VERSION} in \
		${CHROME_VERSION_FILE} file"
	echo ${CHROME_VERSION} > ${CHROME_VERSION_FILE}

	elog "Creating ${CHROME_DISTDIR}/.gclient"
	#until we make the pdf compile on arm.
	#http://code.google.com/p/chrome-os-partner/issues/detail?id=1572
	if use chrome_pdf; then
		elog "Official Build enabling PDF sources"
		create_gclient_file "${CHROME_DISTDIR}" \
			"${PRIMARY_URL}" \
			"${AUXILIARY_URL}" \
			"${REVISION}" \
			0 \
			${USE_TRUNK} \
			|| die "Can't write .gclient file"
	else
		create_gclient_file "${CHROME_DISTDIR}" \
			"${PRIMARY_URL}" \
			"${AUXILIARY_URL}" \
			"${REVISION}" \
			1 \
			${USE_TRUNK} \
			|| die "Can't write .gclient file"
	fi

	elog "Using .gclient ..."
	elog $(cat ${CHROME_DISTDIR}/.gclient)

	pushd "${CHROME_DISTDIR}" || \
		die "Cannot chdir to ${CHROME_DISTDIR}"

	if [ -s patches ]; then
		elog "Reverting previous patches"
		${EGCLIENT} revert --jobs 8 --nohooks || die
		rm patches
	fi
	elog "Syncing google chrome sources using ${EGCLIENT}"
	# We use --force to work around a race condition with
	# checking out cros.git in parallel with the main chrome tree.
	${EGCLIENT} sync --jobs 8 --nohooks --delete_unversioned_trees --force
}

decide_chrome_origin() {
	local chrome_workon="=chromeos-base/chromeos-chrome-9999"
	local cros_workon_file="${ROOT}etc/portage/package.keywords/cros-workon"
	if [ -e "${cros_workon_file}" ] && grep -q "${chrome_workon}" "${cros_workon_file}"; then
		# GERRIT_SOURCE is the default for cros_workon
		# Warn the user if CHROME_ORIGIN is already set
		if [ -n "${CHROME_ORIGIN}" ] && [ "${CHROME_ORIGIN}" != GERRIT_SOURCE ]; then
			ewarn "CHROME_ORIGIN is already set to ${CHROME_ORIGIN}."
			ewarn "This will prevent you from building from gerrit."
			ewarn "Please run 'unset CHROME_ORIGIN' to reset Chrome"
			ewarn "to the default source location."
		fi
		echo "${CHROME_ORIGIN:-GERRIT_SOURCE}"
	else
		# By default, pull from server
		echo "${CHROME_ORIGIN:-SERVER_SOURCE}"
	fi
}

sandboxless_ensure_directory() {
	local dir
	for dir in "$@"; do
		if [[ ! -d "${dir}" ]] ; then
			# We need root access to create these directories, so we need to
			# use sudo. This implicitly disables the sandbox.
			sudo mkdir -p "${dir}" || die
			sudo chown "$PORTAGE_USERNAME:portage" "${dir}" || die
			sudo chmod 0755 "${dir}" || die
		fi
	done
}

src_unpack() {
	tc-export CC CXX
	# CHROME_ROOT is the location where the source code is used for compilation.
	# If we're in SERVER_SOURCE mode, CHROME_ROOT is CHROME_DISTDIR. In LOCAL_SOURCE
	# mode, this directory may be set manually to any directory. It may be mounted
	# into the chroot, so it is not safe to use cp -al for these files.
	# These are set here because $(whoami) returns the proper user here,
	# but 'root' at the root level of the file
	export CHROME_ROOT="${CHROME_ROOT:-/home/$(whoami)/chrome_root}"
	export EGCLIENT="${EGCLIENT:-/home/$(whoami)/depot_tools/gclient}"
	export DEPOT_TOOLS_UPDATE=0

	# Create storage directories.
	sandboxless_ensure_directory "${CHROME_DISTDIR}" "${CHROME_CACHE_DIR}"

	# Copy in credentials to fake home directory so that build process
	# can access svn and ssh if needed.
	mkdir -p ${HOME}
	SUBVERSION_CONFIG_DIR=/home/$(whoami)/.subversion
	if [ -d ${SUBVERSION_CONFIG_DIR} ]; then
		cp -rfp ${SUBVERSION_CONFIG_DIR} ${HOME} || die
	fi
	SSH_CONFIG_DIR=/home/$(whoami)/.ssh
	if [ -d ${SSH_CONFIG_DIR} ]; then
		cp -rfp ${SSH_CONFIG_DIR} ${HOME} || die
	fi

	CHROME_ORIGIN="$(decide_chrome_origin)"

	case "${CHROME_ORIGIN}" in
	LOCAL_SOURCE|SERVER_SOURCE|LOCAL_BINARY|GERRIT_SOURCE)
		elog "CHROME_ORIGIN VALUE is ${CHROME_ORIGIN}"
		;;
	*)
	die "CHROME_ORIGIN not one of LOCAL_SOURCE, SERVER_SOURCE, LOCAL_BINARY, GERRIT_SOURCE"
		;;
	esac

	case "$CHROME_ORIGIN" in
	(SERVER_SOURCE)
		elog "Using CHROME_VERSION = ${CHROME_VERSION}"
		#See if the CHROME_VERSION we used previously was different
		CHROME_VERSION_FILE=${CHROME_DISTDIR}/chrome_version
		if [ -f ${CHROME_VERSION_FILE} ]; then
			OLD_CHROME_VERSION=$(cat ${CHROME_VERSION_FILE})
		fi

		if ! unpack_chrome; then
			if [ $OLD_CHROME_VERSION != $CHROME_VERSION ]; then
				popd
				elog "${EGCLIENT} sync failed and detected version change"
				elog "Attempting to clean up ${CHROME_DISTDIR} and retry"
				elog "OLD CHROME = ${OLD_CHROME_VERSION}"
				elog "NEW CHROME = ${CHROME_VERSION}"
				elog "rm -rf ${CHROME_DISTDIR}"
				rm -rf "${CHROME_DISTDIR}"
				sync
				unpack_chrome || die "${EGCLIENT} sync failed from fresh checkout"
			else
				die "${EGCLIENT} sync failed"
			fi
		fi

		elog "set the LOCAL_SOURCE to ${CHROME_DISTDIR}"
		elog "From this point onwards there is no difference between \
			SERVER_SOURCE and LOCAL_SOURCE, since the fetch is done"
		export CHROME_ROOT=${CHROME_DISTDIR}
		;;
	(GERRIT_SOURCE)
		export CHROME_ROOT="/home/$(whoami)/trunk/chromium"
		# TODO(rcui): Remove all these addwrite hacks once we start
		# building off a copy of the source
		addwrite "${CHROME_ROOT}"
		# Addwrite to .repo because each project's .git directory links
		# to the .repo directory.
		addwrite "/home/$(whoami)/trunk/.repo/"
		# - Make the symlinks from chromium src tree to CrOS source tree
		# writeable so we can run hooks and reset the checkout.
		# - We need to explicitly do this because the symlink points to
		# outside of the CHROME_ROOT.
		# - We don't know which one is a symlink so do it for
		#   all files/directories in src/third_party
		# - chrome_set_ver creates symlinks in src/third_party to simulate
		#   the cros_deps checkout gclient does.  For details, see
		#   http://gerrit.chromium.org/gerrit/#change,5692.
		THIRD_PARTY_DIR="${CHROME_ROOT}/src/third_party"
		for f in `ls -1 ${THIRD_PARTY_DIR}`
		do
			addwrite "${THIRD_PARTY_DIR}/${f}"
		done
		;;
	(LOCAL_SOURCE)
		addwrite "${CHROME_ROOT}"
		;;
	esac

	case "${CHROME_ORIGIN}" in
	LOCAL_SOURCE|SERVER_SOURCE|GERRIT_SOURCE)
		set_build_defines
		;;
	esac

	# FIXME: This is the normal path where ebuild stores its working data.
	# Chrome builds inside distfiles because of speed, so we at least make
	# a symlink here to add compatibility with autotest eclass which uses this.
	ln -sf "${CHROME_ROOT}" "${WORKDIR}/${P}"


	if (use reorder || use pgo) && ! use clang; then
		EGIT_REPO_URI="http://git.chromium.org/chromiumos/profile/chromium.git"
		EGIT_COMMIT="b4d4d1e9e53c841f7e22fb7167485ad405d3766d"
		EGIT_PROJECT="${PN}-pgo"
		if grep -q $EGIT_COMMIT "${CHROME_DISTDIR}/${PGO_SUBDIR}/.git/HEAD"; then
			einfo "PGO repo is up to date."
		else
			einfo "PGO repo not up-to-date. Fetching..."
			local OLD_S="${S}"
			S="${CHROME_DISTDIR}/${PGO_SUBDIR}"
			rm -rf "${S}"
			git_fetch
			pushd "${S}" > /dev/null
			unpack ./profile.tbz2
			popd > /dev/null
			S="${OLD_S}"
		fi
	fi
}

src_prepare() {
	if [[ "$CHROME_ORIGIN" != "LOCAL_SOURCE" ]] && [[ "$CHROME_ORIGIN" != "SERVER_SOURCE" ]] && \
	   [[ "$CHROME_ORIGIN" != "GERRIT_SOURCE" ]]; then
		return
	fi

	elog "${CHROME_ROOT} should be set here properly"
	cd "${CHROME_ROOT}/src" || die "Cannot chdir to ${CHROME_ROOT}"

	# We do symlink creation here if appropriate
	mkdir -p "${CHROME_CACHE_DIR}/src/${BUILD_OUT}"
	if [ ! -z "${BUILD_OUT_SYM}" ]; then
		rm -rf "${BUILD_OUT_SYM}" || die "Could not remove symlink"
		ln -sfT "${CHROME_CACHE_DIR}/src/${BUILD_OUT}" "${BUILD_OUT_SYM}" ||
			die "Could not create symlink for output directory"
		export builddir_name="${BUILD_OUT_SYM}"
	fi

	# Apply patches for non-localsource builds
	if [ "$CHROME_ORIGIN" = "SERVER_SOURCE" ]; then
		for patch_file in ${PATCHES}; do
			einfo Applying $patch_file
			echo $patch_file >> "${CHROME_ROOT}/patches"
			epatch $patch_file
		done
	fi
	wget http://distribution.hexxeh.net/distfiles/ffmpeg.gyp -O third_party/ffmpeg/ffmpeg.gyp

	# The chrome makefiles specify -O and -g flags already, so remove the
	# portage flags.
	filter-flags -g -O*

	if use pgo && ! use clang ; then
		local PROFILE_DIR
		PROFILE_DIR="${CHROME_DISTDIR}/${PGO_SUBDIR}/${CTARGET_default}"
		if [[ -d "${PROFILE_DIR}" ]]; then
			append-flags -fprofile-use \
				-fprofile-correction \
				-Wno-error=coverage-mismatch \
				-fopt-info=0 \
				-fprofile-dir="${PROFILE_DIR}"

			# This is required because gcc currently may crash with an
			# internal compiler error if the profile is stale.
			# http://gcc.gnu.org/bugzilla/show_bug.cgi?id=51975
			# This does not cause performance degradation.
			append-flags -fno-vpt

			# This is required because gcc emits different warnings for PGO
			# vs. non-PGO. PGO may inline different functions from non-PGO,
			# leading to different warnings.
			# crbug.com/112908
			append-flags -Wno-error=maybe-uninitialized
		else
			einfo "USE=+pgo, but ${PROFILE_DIR} not found."
			einfo "Not using pgo. This is expected for arm/x86 boards."
		fi
	fi

	# The hooks may depend on the environment variables we set in this ebuild
	# (i.e., GYP_DEFINES for gyp_chromium)
	ECHROME_SET_VER=${ECHROME_SET_VER:=/home/$(whoami)/trunk/chromite/bin/chrome_set_ver}
	einfo "Building Chrome with the following define options:"
	local opt
	for opt in "${BUILD_DEFINES[@]}"; do
		einfo "${opt}"
	done
	# TODO(rcui): crosbug.com/20435.  Investigate removal of runhooks useflag when
	# chrome build switches to Ninja inside the chroot.
	if use runhooks; then
		if [ "${CHROME_ORIGIN}" = "GERRIT_SOURCE" ]; then
			# Set the dependency repos to the revision specified in the
			# .DEPS.git file, and run the hooks in that file.
			"${ECHROME_SET_VER}" --runhooks || die
		else
			[ -n "${EGCLIENT}" ] || die EGCLIENT unset
			[ -f "$EGCLIENT" ] || die EGCLIENT at "$EGCLIENT" does not exist
			"${EGCLIENT}" runhooks --force || die  "Failed to run  ${EGCLIENT} runhooks"
		fi
	elif [ "${CHROME_ORIGIN}" = "GERRIT_SOURCE" ]; then
		"${ECHROME_SET_VER}" || die
	fi
}

src_configure() {
	tc-export CXX CC AR AS RANLIB LD
	if use gold ; then
		if [ "${GOLD_SET}" != "yes" ]; then
			export GOLD_SET="yes"
			einfo "Using gold from the following location: $(get_binutils_path_gold)"
			export CC="${CC} -B$(get_binutils_path_gold)"
			export CXX="${CXX} -B$(get_binutils_path_gold)"
			export LD="$(get_binutils_path_gold)/ld"
		fi
	else
		ewarn "gold disabled. Using GNU ld."
	fi
}

src_compile() {
	if [[ "$CHROME_ORIGIN" != "LOCAL_SOURCE" ]] && [[ "$CHROME_ORIGIN" != "SERVER_SOURCE" ]] && \
	   [[ "$CHROME_ORIGIN" != "GERRIT_SOURCE" ]]; then
		return
	fi

	cd "${CHROME_ROOT}"/src || die "Cannot chdir to ${CHROME_ROOT}/src"

	if use build_tests; then
		TEST_TARGETS=("${TEST_FILES[@]}"
			pyautolib
			chromedriver
			browser_tests
			sync_integration_tests)
		einfo "Building test targets: ${TEST_TARGETS[@]}"
	fi

	if use_nacl; then
		NACL_TARGETS="nacl_helper_bootstrap nacl_helper"
	fi

	if use drm; then
		time emake -r $(use verbose && echo V=1) \
			BUILDTYPE="${BUILDTYPE}" \
			aura_demo ash_shell \
			chrome chrome_sandbox default_extensions \
			|| die "compilation failed"
	else
		time emake -r $(use verbose && echo V=1) \
			BUILDTYPE="${BUILDTYPE}" \
			chrome chrome_sandbox libosmesa.so default_extensions \
			${NACL_TARGETS} \
			"${TEST_TARGETS[@]}" \
			|| die "compilation failed"
	fi

	if use build_tests; then
		install_chrome_test_resources "${WORKDIR}/test_src"
		install_pyauto_dep_resources "${WORKDIR}/pyauto_src"

		# NOTE: Since chrome is built inside distfiles, we have to get
		# rid of the previous instance first.
		# We remove only what we will overwrite with the mv below.
		local deps="${WORKDIR}/${P}/${AUTOTEST_DEPS}"

		rm -rf "${deps}/chrome_test/test_src"
		mv "${WORKDIR}/test_src" "${deps}/chrome_test/"

		rm -rf "${deps}/pyauto_dep/test_src"
		mv "${WORKDIR}/pyauto_src" "${deps}/pyauto_dep/test_src"

		# HACK: It would make more sense to call autotest_src_prepare in
		# src_prepare, but we need to call install_chrome_test_resources first.
		autotest-deponly_src_prepare

		# Remove .svn dirs
		esvn_clean "${AUTOTEST_WORKDIR}"

		autotest_src_compile
	fi
}

# Turn off the cp -l behavior in autotest, since the source dir and the
# installation dir live on different bind mounts right now.
fast_cp() {
	cp "$@"
}

install_test_resources() {
	# Install test resources from chrome source directory to destination.
	# We keep a cache of test resources inside the chroot to avoid copying
	# multiple times.
	local test_dir="$1"
	shift
	local resource cache dest
	for resource in "$@"; do
		cache=$(dirname "${CHROME_CACHE_DIR}/src/${resource}")
		dest=$(dirname "${test_dir}/${resource}")
		mkdir -p "${cache}" "${dest}"
		rsync -a --delete --exclude=.svn \
			"${CHROME_ROOT}/src/${resource}" "${cache}"
		cp -al "${CHROME_CACHE_DIR}/src/${resource}" "${dest}"
	done
}

install_chrome_test_resources() {
	# NOTE: This is a duplicate from src_install, because it's required here.
	local from="${CHROME_CACHE_DIR}/src/${BUILD_OUT}/${BUILDTYPE}"
	local test_dir="${1}"

	echo Copying Chrome tests into "${test_dir}"
	mkdir -p "${test_dir}/out/Release"

	# Even if chrome_debug_tests is enabled, we don't need to include detailed
	# debug info for tests in the binary package, so save some time by stripping
	# everything but the symbol names. Developers who need more detailed debug
	# info on the tests can use the original unstripped tests from the ${from}
	# directory.
	for f in libppapi_tests.so browser_tests \
			 sync_integration_tests \
			 omx_video_decode_accelerator_unittest; do
		$(tc-getSTRIP) --strip-debug --keep-file-symbols "${from}"/${f} \
			-o "${test_dir}/out/Release/$(basename ${f})"
	done

	# Copy over the test data directory; eventually 'all' non-static
	# Chrome test data will go in here.
	mkdir "${test_dir}"/out/Release/test_data
	cp -al "${from}"/test_data "${test_dir}"/out/Release/

	# Add the fake bidi locale
	mkdir "${test_dir}"/out/Release/pseudo_locales
	cp -al "${from}"/pseudo_locales/fake-bidi.pak \
		"${test_dir}"/out/Release/pseudo_locales

	# Copy over npapi test plugin
	if ! use aura; then
		mkdir -p "${test_dir}"/out/Release/plugins
		cp -al "${from}"/plugins/libnpapi_test_plugin.so \
			"${test_dir}"/out/Release/plugins
	fi

	for f in "${TEST_FILES[@]}"; do
		cp -al "${from}/${f}" "${test_dir}"
	done

	# Install Chrome test resources.
	install_test_resources "${test_dir}" \
		base/base_paths_posix.cc \
		chrome/test/data \
		chrome/test/functional \
		chrome/third_party/mock4js/mock4js.js  \
		content/common/gpu/testdata \
		net/data/ssl/certificates \
		third_party/bidichecker/bidichecker_packaged.js \
		data/page_cycler

	# Add pdf test data
	if use chrome_pdf; then
		install_test_resources "${test_dir}" pdf/test
	fi

	# Remove test binaries from other platforms
	if [ -z "${E_MACHINE}" ]; then
		echo E_MACHINE not defined!
	else
		cd "${test_dir}"/chrome/test
		rm -fv $( scanelf -RmyBF%a . | grep -v -e ^${E_MACHINE} )
	fi

	# Install pyauto test resources.
	# TODO(nirnimesh): Avoid duplicate copies here.
	install_pyauto_dep_resources "${test_dir}"
}

# Set up the PyAuto files also by copying out the files needed for that.
# We create a separate dependency because the chrome_test one is about 350MB
# and PyAuto is a svelte 30MB.
install_pyauto_dep_resources() {
	# NOTE: This is a duplicate from src_install, because it's required here.
	local from="${CHROME_CACHE_DIR}/src/${BUILD_OUT}/${BUILDTYPE}"
	local test_dir="${1}"

	echo "Copying PyAuto framework into ${test_dir}"

	mkdir -p "${test_dir}/out/Release"

	cp -al "${from}"/pyproto "${test_dir}"/out/Release
	cp -al "${from}"/pyautolib.py "${test_dir}"/out/Release

	# Even if chrome_debug_tests is enabled, we don't need to include detailed
	# debug info for tests in the binary package, so save some time by stripping
	# everything but the symbol names. Developers who need more detailed debug
	# info on the tests can use the original unstripped tests from the ${from}
	# directory.
	$(tc-getSTRIP) --strip-debug --keep-file-symbols "${from}"/_pyautolib.so \
		-o "${test_dir}"/out/Release/_pyautolib.so
	$(tc-getSTRIP) --strip-debug --keep-file-symbols "${from}"/chromedriver \
		-o "${test_dir}"/out/Release/chromedriver
	if use component_build; then
		mkdir -p "${test_dir}/out/Release/lib.target"
		local src dst
		for src in "${from}"/lib.target/* ; do
			dst="${test_dir}/out/Release/${src#${from}}"
			$(tc-getSTRIP) --strip-debug --keep-file-symbols \
				"${src}" -o "${dst}"
		done
	fi

	cp -a "${CHROME_ROOT}"/"${AUTOTEST_DEPS}"/pyauto_dep/setup_test_links.sh \
		"${test_dir}"/out/Release

	# Copy PyAuto scripts and suppport libs.
	install_test_resources "${test_dir}" \
		chrome/test/pyautolib \
		net/tools/testserver \
		third_party/pyftpdlib \
		third_party/simplejson \
		third_party/tlslite \
		third_party/webdriver
}

src_install() {
	FROM="${CHROME_CACHE_DIR}/src/${BUILD_OUT}/${BUILDTYPE}"

	# Override default strip flags and lose the '-R .comment'
	# in order to play nice with the crash server.
	if [ -z "${KEEP_CHROME_DEBUG_SYMBOLS}" ]; then
		export PORTAGE_STRIP_FLAGS="--strip-unneeded"
	else
		export PORTAGE_STRIP_FLAGS="--strip-debug --keep-file-symbols"
	fi

	# First, things from the chrome build output directory
	dodir "${CHROME_DIR}"
	dodir "${CHROME_DIR}"/plugins

	exeinto "${CHROME_DIR}"
	doexe "${FROM}"/chrome
	doexe "${FROM}"/libffmpegsumo.so
	doexe "${FROM}"/libosmesa.so
	use drm && doexe "${FROM}"/aura_demo
	use drm && doexe "${FROM}"/ash_shell
	if use chrome_internal && use chrome_pdf; then
		doexe "${FROM}"/libpdf.so
	fi
	exeopts -m4755	# setuid the sandbox
	newexe "${FROM}/chrome_sandbox" chrome-sandbox
	exeopts -m0755

	if use component_build; then
		dodir "${CHROME_DIR}/lib.target"
		exeinto "${CHROME_DIR}/lib.target"
		for f in "${FROM}"/lib.target/*.so; do
			doexe "$f"
		done
		exeinto "${CHROME_DIR}"
	fi

	# enable the chromeos local account, if the environment dictates
	if [ "${CHROMEOS_LOCAL_ACCOUNT}" != "" ]; then
		echo "${CHROMEOS_LOCAL_ACCOUNT}" > "${D_CHROME_DIR}/localaccount"
	fi

	# add executable NaCl binaries
	if use_nacl; then
		doexe "${FROM}"/libppGoogleNaClPluginChrome.so || die
		doexe "${FROM}"/nacl_helper_bootstrap || die
	fi

	insinto "${CHROME_DIR}"
	doins "${FROM}"/chrome-wrapper
	doins "${FROM}"/chrome.pak
	doins -r "${FROM}"/locales
	doins -r "${FROM}"/resources
	doins -r "${FROM}"/extensions
	doins "${FROM}"/resources.pak
	# TODO(sail): Remove these if statements when these .pak files are no longer
	# optional (http://crosbug.com/30473).
	if [ -f "${FROM}"/theme_resources_standard.pak ] ; then
		doins "${FROM}"/theme_resources_standard.pak
	fi
	if [ -f "${FROM}"/theme_resources_touch_1x.pak ] ; then
		doins "${FROM}"/theme_resources_touch_1x.pak
	fi
	if [ -f "${FROM}"/ui_resources_standard.pak ] ; then
		doins "${FROM}"/ui_resources_standard.pak
	fi
	if [ -f "${FROM}"/ui_resources_touch.pak ] ; then
		doins "${FROM}"/ui_resources_touch.pak
	fi
	if [ -f "${FROM}"/theme_resources_2x.pak ] ; then
		doins "${FROM}"/theme_resources_2x.pak
	fi
	if [ -f "${FROM}"/ui_resources_2x.pak ] ; then
		doins "${FROM}"/ui_resources_2x.pak
	fi
	doins "${FROM}"/xdg-settings
	doins "${FROM}"/*.png

	# add non-executable NaCl files
	if use_nacl; then
		doins "${FROM}"/nacl_irt_*.nexe || die
		doins "${FROM}"/nacl_helper || die
	fi

	# Create copy of chromeos_cros_api.h file so that test_build_root can check for
	# libcros compatibility.
	insinto "${CHROME_DIR}"/include
	doins "${CHROME_ROOT}/src/third_party/cros/chromeos_cros_api.h"

	# Copy input_methods.txt so that ibus-m17n can exclude unnnecessary
	# input methods based on the file.
	insinto /usr/share/chromeos-assets/input_methods
	INPUT_METHOD="${CHROME_ROOT}"/src/chrome/browser/chromeos/input_method
	doins "${INPUT_METHOD}"/input_methods.txt

	# Copy org.chromium.LibCrosService.conf, the D-Bus config file for the
	# D-Bus service exported by Chrome.
	insinto /etc/dbus-1/system.d
	DBUS="${CHROME_ROOT}"/src/chrome/browser/chromeos/dbus
	doins "${DBUS}"/org.chromium.LibCrosService.conf

	# Chrome test resources
	# Test binaries are only available when building chrome from source
	if use build_tests && ([[ "${CHROME_ORIGIN}" = "LOCAL_SOURCE" ]] || \
		 [[ "${CHROME_ORIGIN}" = "SERVER_SOURCE" ]] || \
		 [[ "${CHROME_ORIGIN}" = "GERRIT_SOURCE" ]]); then
		autotest-deponly_src_install
	fi

	# Fix some perms
	chmod -R a+r "${D}"
	find "${D}" -perm /111 -print0 | xargs -0 chmod a+x

	# The following symlinks are needed in order to run chrome.
	dosym libnss3.so /usr/lib/libnss3.so.1d
	dosym libnssutil3.so.12 /usr/lib/libnssutil3.so.1d
	dosym libsmime3.so.12 /usr/lib/libsmime3.so.1d
	dosym libssl3.so.12 /usr/lib/libssl3.so.1d
	dosym libplds4.so /usr/lib/libplds4.so.0d
	dosym libplc4.so /usr/lib/libplc4.so.0d
	dosym libnspr4.so /usr/lib/libnspr4.so.0d

	if ! use aura && ( use amd64 || use x86 ); then
		# Install Flash plugin.
		if use chrome_internal; then
			if [ -f "${FROM}/libgcflashplayer.so" ]; then
				# Install Flash from the binary drop.
				exeinto "${CHROME_DIR}"/plugins
				doexe "${FROM}/libgcflashplayer.so"
				doexe "${FROM}/plugin.vch"
			elif [ "${CHROME_ORIGIN}" = "LOCAL_SOURCE" ]; then
				# Install Flash from the local source repository.
				exeinto "${CHROME_DIR}"/plugins
				doexe ${CHROME_ROOT}/src/third_party/adobe/flash/binaries/chromeos/libgcflashplayer.so
				doexe ${CHROME_ROOT}/src/third_party/adobe/flash/binaries/chromeos/plugin.vch
			else
				die No internal Flash plugin.
			fi
		else
			# Use Flash from www-plugins/adobe-flash package.
			dosym /opt/netscape/plugins/libflashplayer.so \
				"${CHROME_DIR}"/plugins/libflashplayer.so
		fi
	fi
}
