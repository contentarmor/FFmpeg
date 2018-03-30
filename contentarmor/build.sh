#!/bin/bash

if [ -z ${COMPILER} ]; then
    COMPILER="g++"
fi

ROOT_DIR="$(dirname $(readlink -f ${0}))"
FFMPEG_BUILD_DIR="${ROOT_DIR}/ffmpeg_out"

DEBFULLNAME="ContentArmor SAS"
DEBEMAIL="support@contentarmor.net"
PKG_VERS="1.1.0"
CONTENT_ARMOR_HOME="/cafvm"
FFMPEG_BUILD_LIB="./ffmpeg_out/lib"
OUT_DEBS_DIR="./debs"
FFMPEG_SRC_DELIVERY="./ca-ffmpeg-3.2.4_${PKG_VERS}"

function LOG
{
    echo "$1"
}

function ERROR
{
    echo $1
    return -1
}

function ASSERT_OK
{
    if [ ${?} -ne 0 ]; then
        echo "${1} aborted$"
        exit -1
    fi
}

if [ "$COMPILER" = "icpc" ];then
  CC=icc
  CXX=icpc
  LD=icc
  AR=xiar
  PKG_NAME="libffmpeg3.2.4i-ca"
else
  CC=gcc
  CXX=g++
  LD=g++
  AR=ar
  PKG_NAME="libffmpeg3.2.4-ca"
fi

CONFIGURE_COMMAND="./configure --enable-shared --disable-doc --disable-programs --disable-static --prefix=${FFMPEG_BUILD_DIR} --cc=$CC --cxx=$CXX --ld=$LD --ar=$AR"
MAKE_COMMAND="make -j16"

function clean
{
    if [ -e ${1} ]; then
        LOG "${FUNCNAME} ${1}"
        rm -rf ${1}
    fi
}

function clean_all
{
    LOG "#### ${FUNCNAME} ###"
    clean "${FFMPEG_BUILD_DIR}"
    clean "./ffmpeg-3.2.4"
    clean "./debian"
    clean "./debs"
    clean "${FFMPEG_SRC_DELIVERY}"
    clean "${FFMPEG_SRC_DELIVERY}.tgz"
    rm -f rpmbuild/SPECS/libffmpeg3.2.4*-ca.spec
    clean rpmbuild/RPMS/x86_64
    clean rpmbuild/SRPMS
    clean rpmbuild/SOURCES
}

function build_ffmpeg
{
    LOG "#### ${FUNCNAME} ###"

    if [ ! -d ffmpeg-3.2.4 ]; then
        ln -s ../ ffmpeg-3.2.4
    fi

    cd  ffmpeg-3.2.4
    ASSERT_OK ${LINENO}

    LOG "============================================================"
    LOG "${CONFIGURE_COMMAND}"
    LOG "============================================================"
    ${CONFIGURE_COMMAND}
    ASSERT_OK ${LINENO}
    LOG "============================================================"
    LOG "${MAKE_COMMAND}"
    LOG "============================================================"
    ${MAKE_COMMAND}
    ASSERT_OK ${LINENO}
    LOG "============================================================"
    LOG  "make instal"
    LOG "============================================================"
    make install
    ASSERT_OK ${LINENO}
    cd ${ROOT_DIR}
}

function create_deb_lib_delivery
{
    LOG "#### ${FUNCNAME} ###"
    export DEBEMAIL DEBFULLNAME
    JOBS=$(grep "^processor" /proc/cpuinfo | wc -l)

    # Get the list of variable to substitute
    VARS=$(cd debian.in; ( grep -Roh '\#<[^>]\+>\#'; \ls -1 ) | sort -u | \sed 's/\#<\([^>]\+\)>\#.*/\1/')
    # Obfuscate the absolute prefix path in CONFIGURE_COMMAND before to add it in the list of substitution
    CONFIGURE_COMMAND=$(echo ${CONFIGURE_COMMAND} | sed "s#--prefix=.*ffmpeg_out#--prefix=${CONTENT_ARMOR_HOME}#")
    # Create the list of substitution
    VAR_SUBS="$(for var in ${VARS}; do eval "val=\$${var}"; echo -n "s%\#<${var}>\#%${val}%g;"; done)"

    which dh_make > /dev/null
    if [ ${?} != 0 ]; then
        ERROR "dh_make is not installed;"
        ERROR "Do: 'sudo apt-get install dh-make'"
        ASSERT_OK ${LINENO}
    fi

    # prepare Debian packaging
    LOG "Prepare Debian packaging"
    dh_make --native --library -y -p ${PKG_NAME}_${PKG_VERS} --copyright=blank
    ASSERT_OK ${LINENO}

    cd debian
    rm -f copyright README* ${PKG_NAME}.cron.d.ex ${PKG_NAME}.default.ex ${PKG_NAME}.doc-base.EX
    rm -f init.d.ex manpage* menu.ex watch.ex *.dirs
    rm docs
    rm -f ${PKG_NAME}*-dev*
    rm -f ${PKG_NAME}*.install
    cd ${ROOT_DIR}

    LOG "Customize the package template"
    # Customize the package template a little bit...
    # - copy other files from debian.in/ to debian/
    #   applying variable subtitution to file name.
    #   The copies of files starting with a shebang are made executable.
    # - Subtitute variables in all files
    for file in debian.in/*; do
        target_file=$(basename "${file}" | \sed "${VAR_SUBS}")
        cp -p ${file} debian/${target_file}
        head -1 debian/${target_file} | \grep -q "^#!" && chmod +x debian/${target_file}
    done

    #Finaly substite a few variables (in the form of #<varname>#)
    for file in debian/*; do
        [ -f ${file} ] && sed -i "${VAR_SUBS}" ${file}
    done

    LOG "Build Debian package"
    dpkg-buildpackage -rfakeroot -b -us -uc ${DEBBUILDOPTS} -j${JOBS};
    ASSERT_OK ${LINENO}

    LOG "Move packages in ${OUT_DEBS_DIR}"
    mkdir -p ${OUT_DEBS_DIR}
    ASSERT_OK ${LINENO}
    find ../ -maxdepth 1 -regextype posix-extended -regex ".*${PKG_NAME}.*\.(changes|deb|dsc|tar\.gz)" -exec mv {} ${OUT_DEBS_DIR} \;
    ASSERT_OK ${LINENO}

}

function create_rpm_lib_delivery
{
    LOG "#### ${FUNCNAME} ###"

    which rpmbuild > /dev/null
    if [ ${?} != 0 ]; then
        ERROR "rpmbuild is not installed;"
        ERROR "Do: 'sudo yum install rpm-build'"
        ASSERT_OK ${LINENO}
    fi

    # prepare packaging
    RPM_BUILDROOT=rpmbuild/BUILDROOT

    mkdir -p ${RPM_BUILDROOT}
    mv -f ${FFMPEG_BUILD_DIR} ${RPM_BUILDROOT}/${CONTENT_ARMOR_HOME}
    mkdir -p ${RPM_BUILDROOT}/usr/share/doc/${PKG_NAME}
    cp debian.in/README debian.in/changelog ${RPM_BUILDROOT}/usr/share/doc/${PKG_NAME}/
    cp debian.in/#\<PKG_NAME\>#.copyright ${RPM_BUILDROOT}/usr/share/doc/${PKG_NAME}/${PKG_NAME}.copyright

    # substitute a few variables (in the form of #<varname>#)

    cp rpmbuild/SPECS/#\<PKG_NAME\>#.spec rpmbuild/SPECS/${PKG_NAME}.spec
    # Update the absolute prefix path in CONFIGURE_COMMAND before to add it in the list of substitution
    CONFIGURE_COMMAND=$(echo ${CONFIGURE_COMMAND} | sed "s#--prefix=.*ffmpeg_out#--prefix=${CONTENT_ARMOR_HOME}#")
    # Create the list of substitution
    VARS=$(grep -oh '\#<[^>]\+>\#' rpmbuild/SPECS/${PKG_NAME}.spec ${RPM_BUILDROOT}/usr/share/doc/libffmpeg3.2.4-ca/* | sort -u | \sed 's/\#<\([^>]\+\)>\#.*/\1/')
    VAR_SUBS="$(for var in ${VARS}; do eval "val=\$${var}"; echo -n "s%\#<${var}>\#%${val}%g;"; done)"
    for file in rpmbuild/SPECS/${PKG_NAME}.spec ${RPM_BUILDROOT}/usr/share/doc/*; do
        [ -f ${file} ] && sed -i "${VAR_SUBS}" ${file}
    done
    
    for file in ${RPM_BUILDROOT}/${CONTENT_ARMOR_HOME}/lib/pkgconfig/*; do
        [ -f ${file} ] && sed -i "s%${FFMPEG_BUILD_DIR}%${CONTENT_ARMOR_HOME}%g;" ${file}
    done

    LOG "Build package"
    rpmbuild -bb --define "_topdir rpmbuild" --buildroot=$(pwd)/rpmbuild/BUILDROOT rpmbuild/SPECS/${PKG_NAME}.spec -vv
    ASSERT_OK ${LINENO}
}

######################################################

case "$1" in
    clean)
        clean_all
        ;;
    deb)
        build_ffmpeg
        create_deb_lib_delivery
        ;;
    rpm)
        if cat /etc/os-release | grep -qi ubuntu ; then
            ERROR "Use rpm based system to create rpm package"
            ASSERT_OK ${LINENO}
        fi

        build_ffmpeg
        create_rpm_lib_delivery
        ;;
    *)
        LOG "Usage: $0 {clean|deb|tgz}"
        LOG "    clean : clean the current directory"
        LOG "    deb   : compile and package FFmpeg shared libraries in a debian package"
        LOG "    rpm   : compile and package FFmpeg shared libraries in a RPM package"
        exit 1
        ;;
esac

exit 0
