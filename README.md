# XZ Utils 5.8.3 for SCO OpenServer 5

A working build of [XZ Utils](https://tukaani.org/xz/) **5.8.3** for **SCO
OpenServer 5.0.7**, which ships no `xz` at all.

```
$ xz --version
xz (XZ Utils) 5.8.3
liblzma 5.8.3
```

## Why

Compression on a stock OpenServer box stops at `gzip` and `bzip2`. Most
upstream projects now publish `.tar.xz` and nothing else, so without this a
SCO machine cannot unpack a current source tarball or a modern backup archive
without borrowing another machine to do it.

It is also an enabler. Every future port gets easier once the box can open the
archives that software is actually distributed in.

5.8.3 is the current release rather than the old 5.2 branch, so this is a
version still receiving upstream security fixes.

## Install

> **Fresh SCO box?** Install
> [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> and [GNU tar](https://github.com/tachytelic/tar-1.34-for-SCO-OpenServer-5)
> first. The full set of builds is indexed at
> [tachytelic.net](https://tachytelic.net/2017/07/sco-openserver-5-binaries/).

The prebuilt tarball extracts from `/` into `/usr/local/xz-5.8.3`, and includes
symlinks into `/usr/local/bin`, which is already on the stock OpenServer `PATH`:

```sh
curl -LO https://github.com/tachytelic/XZ-5.8.3-for-SCO-OpenServer-5/releases/download/v1.0.0/xz-5.8.3-sco.tar.gz
cd / && gunzip -c xz-5.8.3-sco.tar.gz | /usr/bin/tar xf -
xz --version
```

Nothing on OpenServer is called `xz`, `lzma` or `unxz`, so no stock tool is
shadowed and no `g` prefix is needed.

### It wires straight into GNU tar

Because the tools land on the default `PATH`, `gtar` finds them by itself:

```sh
gtar xJf something.tar.xz      # unpack a modern tarball
gtar cJf archive.tar.xz dir/   # create one
xz -dc something.tar.xz | gtar xf -    # or do it by hand
```

## Building from source

```sh
CC=/usr/local/bin/gcc-3.4.6 ./build.sh
```

Needs GCC 3.4.6 or newer, since xz requires C99 and SCO's stock 2.95.3 is C89
only. It also needs **bash**: xz's `configure` does not survive SCO's `/bin/sh`,
which is the original Bourne shell, and stops with

```
./configure[932]: : is not an identifier
```

Upstream source, verified before building:

```
xz-5.8.3.tar.gz
sha256  3d3a1b973af218114f4f889bbaa2f4c037deaae0c8e815eec381c3d546b974a0
```

Note that `build.sh` fetches the `.tar.gz` rather than the `.tar.xz`. A machine
that does not yet have xz cannot unpack the `.tar.xz`, which is the entire
reason this port exists.

### The two patches

Both are in `patches/xz-5.8.3-sco.patch`, 15 added lines between them.

**`src/xz/hardware.c`: `RLIM_SAVED_CUR` and `RLIM_SAVED_MAX` are missing.**
OpenServer's `<sys/resource.h>` defines `RLIM_INFINITY` and `rlim_t` but not
these two. Upstream's own comment beside the code says that where they are used
"for us these are the same thing as no limit at all", so the patch defines them
as `RLIM_INFINITY` when absent, which is exactly that meaning.

**`src/xz/file_io.c`: `fsync()` on a directory descriptor fails.** After writing
the output file, xz calls `fsync()` on the containing directory. OpenServer
returns `EBADF`, xz treats that as fatal, and the result is that

```sh
xz somefile
```

prints `Synchronizing the directory of the file failed: Bad file number` and
produces no `.xz` file at all. This is not cosmetic; it breaks the program's
main purpose. It only shows up when writing a real file, so a quick test with
`xz -c` to standard output will not reveal it.

Upstream already handles this for two other platforms:

```c
#if !defined(TUKLIB_DOSLIKE) && !defined(_AIX) && !defined(__QNX__)
	// On AIX, this would fail with EBADF.
	// On QNX, this would fail with EINVAL.
```

SCO fails the same way AIX does, so the patch adds `_SCO_DS` to that list.
**Worth reporting upstream**, since it is a one-line addition to a guard they
already maintain.

### Configure warnings

Two are expected and harmless:

```
No supported method to detect the amount of RAM.
No supported method to detect the number of CPU cores.
```

xz then assumes 128 MiB and one processor. Compression and decompression memory
limits are left disabled either way, so this affects only the defaults for
multi-threaded work, and this is a `--disable-threads` build.

## Test results

`gmake check`: **16 pass, 3 skip, 0 fail.**

Verified beyond the suite on OpenServer 5.0.7:

* compress and decompress to and from standard output, byte identical
* compress and decompress real files in place, checksum verified
* unpacking a genuine `.tar.xz` and getting the complete tree
* `gtar xJf`, `gtar cJf` and `gtar tJf`
* `xzgrep`, `xzdiff` and `xzmore`, which are `#!/bin/sh` scripts and therefore
  run under the Bourne shell rather than bash
* `ldd` reports a single dependency, `/usr/lib/libc.so.1`, so the binaries are
  self-contained

## Licence

The build script and patch here are MIT, see [LICENSE](LICENSE). XZ Utils
itself is public domain and 0BSD; see `COPYING` in the upstream tarball.
