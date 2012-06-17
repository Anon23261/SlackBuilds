#!/bin/sh

# Copyright (c) 2006,2007 Eric Hameleers <alien@slackware.com>
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------

# Modified to SBo format with the help of Yalla-One
# Version bump and various other changes by Robby Workman
# New version bump and various other changes by ponce
# No additional license terms added

PRGNAM=clamav
VERSION=${VERSION:-0.97.5}
BUILD=${BUILD:-1}
TAG=${TAG:-_SBo}

if [ -z "$ARCH" ]; then
  case "$( uname -m )" in
    i?86) ARCH=i486 ;;
    arm*) ARCH=arm ;;
       *) ARCH=$( uname -m ) ;;
  esac
fi

CWD=$(pwd)
TMP=${TMP:-/tmp/SBo}
PKG="$TMP/package-$PRGNAM"
OUTPUT=${OUTPUT:-/tmp}

# Two letter country code
# See http://www.iana.org/cctld/cctld-whois.htm for options
COUNTRY=${COUNTRY:-us}

if [ "$ARCH" = "i486" ]; then
  SLKCFLAGS="-O2 -march=i486 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "$ARCH" = "i686" ]; then
  SLKCFLAGS="-O2 -march=i686 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "$ARCH" = "x86_64" ]; then
  SLKCFLAGS="-O2 -fPIC"
  LIBDIRSUFFIX="64"
else
  SLKCFLAGS="-O2"
  LIBDIRSUFFIX=""
fi

bailout() {
  printf "\n  You must have a \"clamav\" user and group in order to run this script.
  Add them with something like this:
     groupadd -g 210 clamav
     useradd -u 210 -d /dev/null -s /bin/false -g clamav clamav\n"
  exit 1
}

# Check for ClamAV user and group availability
if ! getent group clamav 2>&1 > /dev/null; then
  bailout ;
elif ! getent passwd clamav 2>&1 > /dev/null; then
  bailout ;
fi

set -e

rm -rf $PKG
mkdir -p $TMP $PKG $OUTPUT
cd $TMP
rm -rf $PRGNAM-$VERSION
tar xvf $CWD/$PRGNAM-$VERSION.tar.gz
cd $PRGNAM-$VERSION || exit 1
chown -R root:root .
chmod -R u+w,go+r-w,a-s .

# Specify the desired mirror in the update config file
# http://www.iana.org/cctld/cctld-whois.htm
sed -i "s/^\#DatabaseMirror.*/DatabaseMirror db.${COUNTRY}.clamav.net/" etc/freshclam.conf

sed \
  -e "s/^Example/#Example/" \
  -e "s/^\#LogSyslog/LogSyslog/" \
  -e "s/^\#LogFacility/LogFacility/" \
  -e "s/^\#PidFile.*/PidFile \/var\/run\/clamav\/freshclam.pid/" \
  -e "s/^\#UpdateLogFile.*/UpdateLogFile \/var\/log\/clamav\/freshclam.log/" \
  -e "s/^\#AllowSupplementaryGroups.*/AllowSupplementaryGroups yes/" \
  -e "s/^\#DatabaseOwner.*/DatabaseOwner clamav/" \
  -e "s/^\#NotifyClamd.*/NotifyClamd \/etc\/clamd.conf/" \
  -i etc/freshclam.conf
sed \
  -e "s/^Example/#Example/" \
  -e "s/^\#LogSyslog/LogSyslog/" \
  -e "s/^\#LogFacility/LogFacility/" \
  -e "s/^\#LogFile\ .*/LogFile \/var\/log\/clamav\/clamd.log/" \
  -e "s/^\#PidFile.*/PidFile \/var\/run\/clamav\/clamd.pid/" \
  -e "s/^\#LocalSocket\ .*/LocalSocket \/var\/run\/clamav\/clamd.socket/" \
  -e "s/^\#LocalSocketGroup.*/LocalSocketGroup clamav/" \
  -e "s/^\#LocalSocketMode/LocalSocketMode/" \
  -e "s/^\#FixStaleSocket/FixStaleSocket/" \
  -e "s/^\#User.*/User clamav/" \
  -e "s/^\#AllowSupplementaryGroups.*/AllowSupplementaryGroups yes/" \
  -e "s/^\#ExitOnOOM/ExitOnOOM/" \
  -i etc/clamd.conf
exit
CFLAGS="$SLKCFLAGS" \
CXXFLAGS="$SLKCFLAGS" \
./configure \
  --prefix=/usr \
  --libdir=/usr/lib${LIBDIRSUFFIX} \
  --localstatedir=/var \
  --sysconfdir=/etc \
  --mandir=/usr/man \
  --with-user=clamav \
  --with-group=clamav \
  --with-dbdir=/var/lib/clamav \
  --enable-milter \
  --enable-id-check \
  --disable-static \
  --disable-experimental \
  --build=$ARCH-slackware-linux

make V=1
make install DESTDIR=$PKG

# Prepare the config files:
for cf in clamd freshclam clamav-milter; do
  mv $PKG/etc/$cf.conf $PKG/etc/$cf.conf.new
done

# Our rc script and logrotate entry:
install -D -m 0755 $CWD/rc.clamav $PKG/etc/rc.d/rc.clamav.new
install -D -m 0644 $CWD/logrotate.clamav $PKG/etc/logrotate.d/clamav

# Fixup some ownership and permissions issues
chown -R root:root $PKG
chmod -R o-w $PKG
chown clamav $PKG/usr/sbin/clamav-milter
chmod 4700 $PKG/usr/sbin/clamav-milter
chmod 0770 $PKG/var/lib/clamav
chmod 0660 $PKG/var/lib/clamav/*

# Create pid, socket and log directories
mkdir -p $PKG/var/{log,run}/clamav
chmod 771 $PKG/var/{log,run}/clamav

# Create log files in such a way that they won't clobber existing ones
touch $PKG/var/log/clamav/{clamd,freshclam}.log.new
chmod 660 $PKG/var/log/clamav/{clamd,freshclam}.log.new

chown -R clamav:clamav $PKG/var/{lib,log,run}/clamav

find $PKG | xargs file | grep -e "executable" -e "shared object" | grep ELF \
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true

# Compress the man page(s)
find $PKG/usr/man -type f -name "*.?" -exec gzip -9f {} \;

mkdir -p $PKG/usr/doc/$PRGNAM-$VERSION
cp -a \
  AUTHORS BUGS COPYING ChangeLog FAQ INSTALL NEWS README UPGRADE \
  docs/*.pdf docs/html examples $PKG/usr/doc/$PRGNAM-$VERSION
chmod 0644 $PKG/usr/doc/$PRGNAM-$VERSION/*
cat $CWD/$PRGNAM.SlackBuild > $PKG/usr/doc/$PRGNAM-$VERSION/$PRGNAM.SlackBuild
cat $CWD/README.SLACKWARE > $PKG/usr/doc/$PRGNAM-$VERSION/README.SLACKWARE

mkdir -p $PKG/install
cat $CWD/slack-desc > $PKG/install/slack-desc
cat $CWD/doinst.sh > $PKG/install/doinst.sh

cd $PKG
/sbin/makepkg -l y -c n $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD$TAG.${PKGTYPE:-tgz}
