This tarball provides the following elements :
.
├── build.sh            : a script to compile and package the FFmpeg shared libraries in a debian package
├── debian.in           : a directory that contains template files needed to generate the debian package
├── ffmpeg-3.2.4.tar.xz : the FFmpeg source code used to generate FFmpeg shared libraries used by some ContentArmor softwares
└── readme.txt          : this file

To compile and generate the debian package, do :

    build.sh clean
    build.sh deb

To compile and generate the RPM package, do :

    build.sh clean
    build.sh rpm

By default build.sh compile FFmpeg source with g++ and provide a debian package named libffmpeg2.8-ca_<PACKAGE_VERSION>

