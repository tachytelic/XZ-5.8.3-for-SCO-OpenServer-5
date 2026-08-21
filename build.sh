#!/bin/sh
# Build XZ Utils 5.8.3 natively on SCO OpenServer 5.0.7.
#
# Run on the SCO machine, in a writable directory (use /u1, not /).
# Installs to /usr/local/xz-5.8.3 by default.
#
# Needs:
#   - GCC 3.4.6 or newer. The stock 2.95.3 is C89 only and xz requires C99.
#   - bash. Configure does not survive SCO's /bin/sh, which is the original
#     Bourne shell; it fails with "is not an identifier".
#
#   CC=/usr/local/bin/gcc-3.4.6 ./build.sh

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=5.8.3
TARBALL=xz-${VERSION}.tar.gz
SRCDIR=xz-${VERSION}
PREFIX=${PREFIX:-/usr/local/xz-${VERSION}}
URL=https://github.com/tukaani-project/xz/releases/download/v${VERSION}/${TARBALL}

CC="${CC:-/usr/local/bin/gcc-3.4.6}"
export CC
PATH=/usr/local/bin:/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

BASH=/usr/local/bin/bash
if [ ! -x "$BASH" ]; then
    echo "ERROR: $BASH not found."
    echo "xz's configure script does not run under SCO's /bin/sh."
    echo "Install bash first:"
    echo "  https://github.com/tachytelic/Bash-3.2.57-for-SCO-OpenServer-5"
    exit 1
fi

# Deliberately the .tar.gz, not the .tar.xz. A machine that does not yet
# have xz cannot unpack the .tar.xz, which is the whole reason for this port.
if [ ! -f "$TARBALL" ]; then
    if which curl >/dev/null 2>&1; then
        curl -kLO "$URL" || true
    elif which wget >/dev/null 2>&1; then
        wget --no-check-certificate "$URL" || true
    fi
fi

if [ ! -s "$TARBALL" ]; then
    rm -f "$TARBALL"
    echo "ERROR: could not download $TARBALL. Copy it across by other means:"
    echo "  $URL"
    exit 1
fi

rm -rf "$SRCDIR"
gtar xzf "$TARBALL" 2>/dev/null || tar xzf "$TARBALL"
find "$SRCDIR" -name 'PaxHeaders*' -exec rm -rf {} + 2>/dev/null || true

cd "$SRCDIR"

echo "Applying SCO patch..."
patch -p1 < "$SCRIPT_DIR/patches/xz-${VERSION}-sco.patch"

echo "Configuring..."
# --disable-threads: OpenServer has no usable pthreads for this.
# --disable-shared:  keeps the binaries self-contained; they then need
#                    nothing beyond /usr/lib/libc.so.1.
# --disable-nls:     no gettext on the box.
# CONFIG_SHELL:      sub-configures must use bash too.
CONFIG_SHELL="$BASH"; export CONFIG_SHELL
"$BASH" ./configure \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --disable-nls --disable-threads

echo "Compiling..."
gmake

echo
echo "Built. Check it works:"
echo "  ./src/xz/xz --version"
echo "  ./src/xz/xz -9 -c somefile > somefile.xz && ./src/xz/xz -d -c somefile.xz | cmp - somefile"
echo
echo "Optionally run the test suite (expect 16 pass, 3 skip, 0 fail):"
echo "  gmake check"
echo
echo "To install to $PREFIX:"
echo "  gmake install"
echo
echo "Then link the tools onto the default PATH so gtar -J works:"
echo "  for b in xz unxz xzcat xzdec lzma unlzma lzcat xzgrep xzdiff xzless xzmore lzmainfo; do"
echo "      ln -sf $PREFIX/bin/\$b /usr/local/bin/\$b"
echo "  done"
