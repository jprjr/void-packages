# This hook creates wrappers for foo-config scripts in cross builds.
#
# Wrappers are created in ${wrksrc}/.xbps/bin and this path is appended
# to make configure scripts find them.

generic_wrapper() {
	local wrapper="$1"
	[ ! -x ${XBPS_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0

	echo "#!/bin/sh" >> ${XBPS_WRAPPERDIR}/${wrapper}
	echo "exec ${XBPS_CROSS_BASE}/usr/bin/${wrapper} --prefix=${XBPS_CROSS_BASE}/usr \"\$@\"" >> ${XBPS_WRAPPERDIR}/${wrapper}
	chmod 755 ${XBPS_WRAPPERDIR}/${wrapper}
}

generic_wrapper2() {
	local wrapper="$1"

	[ ! -x ${XBPS_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0

	cat >>${XBPS_WRAPPERDIR}/${wrapper}<<_EOF
#!/bin/sh
if [ "\$1" = "--prefix" ]; then
	echo "${XBPS_CROSS_BASE}/usr"
elif [ "\$1" = "--cflags" ]; then
	${XBPS_CROSS_BASE}/usr/bin/${wrapper} --cflags | sed -e "s,-I/usr/include,-I${XBPS_CROSS_BASE}/usr/include,g"
elif [ "\$1" = "--libs" ]; then
	${XBPS_CROSS_BASE}/usr/bin/${wrapper} --libs | sed -e "s,-L/usr/lib,-L${XBPS_CROSS_BASE}/usr/lib,g"
else
	exec ${XBPS_CROSS_BASE}/usr/bin/${wrapper} "\$@"
fi
exit \$?
_EOF
	chmod 755 ${XBPS_WRAPPERDIR}/${wrapper}
}

generic_wrapper3() {
	local wrapper="$1"
	[ ! -x ${XBPS_CROSS_BASE}/usr/bin/${wrapper} ] && return 0
	[ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0

	cp ${XBPS_CROSS_BASE}/usr/bin/${wrapper} ${XBPS_WRAPPERDIR}
	sed -e "s,/usr/include,${XBPS_CROSS_BASE}/usr/include,g" -i ${XBPS_WRAPPERDIR}/${wrapper}
	sed -e "s,^libdir=.*,libdir=${XBPS_CROSS_BASE}/usr/lib,g" -i ${XBPS_WRAPPERDIR}/${wrapper}
	sed -e "s,^prefix=.*,prefix=${XBPS_CROSS_BASE}/usr," -i ${XBPS_WRAPPERDIR}/${wrapper}

	chmod 755 ${XBPS_WRAPPERDIR}/${wrapper}
}

python_wrapper() {
	local wrapper="$1" version="$2"

	[ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0
	cat >>${XBPS_WRAPPERDIR}/${wrapper}<<_EOF
#!/bin/sh
if [ "\$1" = "--includes" ]; then
	echo "-I${XBPS_CROSS_BASE}/usr/include/python${version}"
fi
exit \$?
_EOF
	chmod 755 ${XBPS_WRAPPERDIR}/${wrapper}
}

pkgconfig_wrapper() {
	if [ ! -x /usr/bin/pkg-config ]; then
		return 0
	fi
	[ -x ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-pkg-config ] && return 0
	cat >>${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-pkg-config<<_EOF
#!/bin/sh

export PKG_CONFIG_SYSROOT_DIR="$XBPS_CROSS_BASE"
export PKG_CONFIG_PATH="$XBPS_CROSS_BASE/lib/pkgconfig:$XBPS_CROSS_BASE/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR="$XBPS_CROSS_BASE/lib/pkgconfig"
exec /usr/bin/pkg-config "\$@"
_EOF
	chmod 755 ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-pkg-config
	ln -sf ${XBPS_CROSS_TRIPLET}-pkg-config ${XBPS_WRAPPERDIR}/pkg-config
}

llvmconfig_wrapper() {
	if [ ! -x /usr/bin/llvm-config ]; then
		return 0
	fi
	[ -x ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-llvm-config ] && return 0
	cat >>${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-llvm-config<<_EOF
#!/bin/sh
arg="\$1"
shift
if [ "\$arg" = "--prefix" ]; then
	echo "${XBPS_CROSS_BASE}/usr"
elif [ "\$arg" = "--bindir" ]; then
	echo "${XBPS_WRAPPERDIR}"
elif [ "\$arg" = "--includedir" ]; then
	/usr/bin/llvm-config --includedir | sed -e "s,/usr/include,${XBPS_CROSS_BASE}/usr/include,g"
elif [ "\$arg" = "--libdir" ]; then
	/usr/bin/llvm-config --libdir | sed -e "s,/usr/lib,${XBPS_CROSS_BASE}/usr/lib,g"
elif [ "\$arg" = "--cppflags" ]; then
	/usr/bin/llvm-config --cppflags | sed -e "s,-I/usr/include,-I${XBPS_CROSS_BASE}/usr/include,g"
elif [ "\$arg" = "--cflags" ]; then
	/usr/bin/llvm-config --cflags | sed -e "s,-I/usr/include,-I${XBPS_CROSS_BASE}/usr/include,g"
elif [ "\$arg" = "--cxxflags" ]; then
	/usr/bin/llvm-config --cxxflags | sed -e "s,-I/usr/include,-I${XBPS_CROSS_BASE}/usr/include,g"
elif [ "\$arg" = "--ldflags" ]; then
	/usr/bin/llvm-config --ldflags | sed -e "s,-L/usr/lib,-L${XBPS_CROSS_BASE}/usr/lib,g"
elif [ "\$arg" = "--libfiles" ]; then
	/usr/bin/llvm-config --libfiles "\$@" | sed -e "s,/usr/lib,${XBPS_CROSS_BASE}/usr/lib,g"
else
	exec /usr/bin/llvm-config "\$arg" "\$@"
fi
exit \$?
_EOF
	chmod 755 ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-llvm-config
	ln -sf ${XBPS_CROSS_TRIPLET}-llvm-config ${XBPS_WRAPPERDIR}/llvm-config
}

clang_wrapper() {
	local wrapper="$1"

	[ ! -x /usr/bin/${wrapper} ] && return 0
	[ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0

    #clang_opts="-isysroot ${XBPS_CROSS_BASE}  -isystem /usr/include -isystem /usr/lib/clang/3.6.0/include"
    #if [ "$wrapper" = "clang++" ] ; then
    #    clang_opts+=" -cxx-isystem /usr/include/c++/4.9.2 -cxx-isystem /usr/include/c++/4.9.2/${XBPS_CROSS_TRIPLET}"
    #fi
    clang_opts=" --gcc-toolchain=/usr/lib/gcc/${XBPS_CROSS_TRIPLET}/4.9.2"
    clang_opts+=" -v"
    clang_opts+=" -nostdinc"
    clang_opts+=" -nostdinc++"
    clang_opts+=" -Wl,-L/usr/lib/gcc/${XBPS_CROSS_TRIPLET}/4.9.2"
    clang_opts+=" --sysroot=${XBPS_CROSS_BASE}"
    clang_opts+=" -isysroot ${XBPS_CROSS_BASE}"
    clang_opts+=" -isystem ${XBPS_CROSS_BASE}/usr/include"
    clang_opts+=" -isystem ${XBPS_CROSS_BASE}/usr/lib/clang/3.6.0/include"
    clang_opts+=" -cxx-isystem ${XBPS_CROSS_BASE}/usr/include/c++/4.9.2"
    clang_opts+=" -cxx-isystem ${XBPS_CROSS_BASE}/usr/include/c++/4.9.2/${XBPS_CROSS_TRIPLET}"
    clang_opts+=" --target=${XBPS_CROSS_TRIPLET}"

	cat >>${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-${wrapper}<<_EOF
#!/bin/sh
exec /usr/bin/${wrapper} ${clang_opts} "\$@"
_EOF
	chmod 755 ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-${wrapper}
    ln -sf ${XBPS_CROSS_TRIPLET}-${wrapper} ${XBPS_WRAPPERDIR}/${wrapper}
}

link_wrapper() {
    local wrapper="$1"
    [ ! -x /usr/bin/${wrapper} ] && return 0
    [ -x ${XBPS_WRAPPERDIR}/${wrapper} ] && return 0
    ln -sf /usr/bin/${wrapper} ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-${wrapper}
    ln -sf ${XBPS_WRAPPERDIR}/${XBPS_CROSS_TRIPLET}-${wrapper} ${XBPS_WRAPPERDIR}/${wrapper}
}

install_wrappers() {
	for f in ${XBPS_COMMONDIR}/wrappers/*.sh; do
		install -m0755 ${f} ${XBPS_WRAPPERDIR}/$(basename ${f%.sh})
	done
}

hook() {
	export PATH="$XBPS_WRAPPERDIR:$PATH"

	install_wrappers

	[ -z "$CROSS_BUILD" ] && return 0

	pkgconfig_wrapper
	generic_wrapper icu-config
	generic_wrapper libgcrypt-config
	generic_wrapper freetype-config
	generic_wrapper sdl-config
	generic_wrapper sdl2-config
	generic_wrapper gpgme-config
	generic_wrapper imlib2-config
	generic_wrapper libmikmod-config
	generic_wrapper pcre-config
	generic_wrapper2 curl-config
	generic_wrapper2 gpg-error-config
	generic_wrapper2 libassuan-config
	generic_wrapper2 llvm-config
	generic_wrapper2 mysql_config
	generic_wrapper3 libpng-config
	generic_wrapper3 xmlrpc-c-config
	generic_wrapper3 krb5-config
	generic_wrapper3 taglib-config
	generic_wrapper3 cups-config
	generic_wrapper3 Magick-config
	generic_wrapper3 fltk-config
	generic_wrapper3 xslt-config
	generic_wrapper3 xml2-config
	generic_wrapper3 fox-config
	generic_wrapper3 xapian-config
	generic_wrapper3 ncurses5-config
	generic_wrapper3 ncursesw5-config
	generic_wrapper3 libetpan-config
	python_wrapper python-config 2.7
	python_wrapper python3.4-config 3.4m
    llvmconfig_wrapper
    clang_wrapper clang
    clang_wrapper clang++
    link_wrapper clang-tblgen
    link_wrapper c-index-test
    link_wrapper clang-check
    link_wrapper clang-format
	link_wrapper llvm-size
	link_wrapper llvm-link
	link_wrapper llvm-objdump
	link_wrapper opt
	link_wrapper count
	link_wrapper llvm-extract
	link_wrapper not
	link_wrapper llvm-ar
	link_wrapper macho-dump
	link_wrapper llvm-tblgen
	link_wrapper bugpoint
	link_wrapper llvm-mc
	link_wrapper llvm-dis
	link_wrapper llvm-dsymutil
	link_wrapper llvm-nm
	link_wrapper yaml2obj
	link_wrapper llvm-as
	link_wrapper llvm-readobj
	link_wrapper llvm-diff
	link_wrapper FileCheck
	link_wrapper llvm-ranlib
	link_wrapper verify-uselistorder
	link_wrapper llvm-mcmarkup
	link_wrapper lli
	link_wrapper llvm-vtabledump
	link_wrapper llvm-cov
	link_wrapper lli-child-target
	link_wrapper llvm-rtdyld
	link_wrapper llvm-symbolizer
	link_wrapper obj2yaml
	link_wrapper llvm-dwarfdump
	link_wrapper llvm-bcanalyzer
	link_wrapper llvm-profdata
	link_wrapper llc
	link_wrapper llvm-stress
}
