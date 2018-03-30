Name:           #<PKG_NAME>#
Version:        #<PKG_VERS>#
Release:        1
ExclusiveArch:  x86_64
Summary:        FFmpeg shared libraries build by ContentArmor SAS.
License:        see /usr/share/doc/libffmpeg2.8-ca/copyright
Vendor:         ContentArmor SAS (http://contentarmor.net/)
Packager:       ContentArmor SAS <support@contentarmor.net>
URL:            http://ffmpeg.org/

Prefix: #<CONTENT_ARMOR_HOME>#
Prefix: /usr

%description 
FFmpeg shared libraries build using #<COMPILER># from vanilla FFmpeg sources, without any modification from ContentArmor SAS.

%postun
/sbin/ldconfig

%files
#<CONTENT_ARMOR_HOME>#/lib/*.so*
%docdir /usr/share/doc/#<PKG_NAME>#
/usr/share/doc/#<PKG_NAME>#/*

%package dev
Summary:        Development files for FFmpeg shared libraries build by ContentArmor SAS.

%description dev
Development files for FFmpeg shared libraries build by ContentArmor SAS.

%files dev
#<CONTENT_ARMOR_HOME>#/include/*
#<CONTENT_ARMOR_HOME>#/lib/pkgconfig/*
