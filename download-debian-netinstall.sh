#!/bin/bash
# Public Domain, use at own risk, etc. etc. etc.
#
# Example ~/.proxy.conf (defines how to use a local proxy):
#
# PROX=192.168.0.80
# PORT=8080
#
# export http_proxy=http://$PROX:$PORT/
# export https_proxy=http://$PROX:$PORT/
#
# export MAVEN_OPTS="-Dhttp.proxyHost=$PROX -Dhttp.proxyPort=$PORT -Dhttps.proxyHost=$PROX -Dhttps.proxyPort=$PORT -DproxyHost=$PROX -DproxyPort=$PORT"

DEST="${1%/}"
DEST="${DEST##*/}"

OOPS() { for a; do echo "OOPS: $a"; done >&2; exit 23; }
x() { "$@"; }
i() { local e=$?; "$@"; return $e; }
o() { "$@" || OOPS "exec $?: $*"; }
v() { local -n __var__="$1"; __var__="$("${@:2}")"; }
get() { v "$1" which -- "$2" || OOPS "missing $2" "try: sudo apt-get install ${3:-$2}"; }

get WGET	wget
get GPG		gpg
# assume that following are always installed: grep fgrep readlink rm ln

EX='
see also: http://cdimage.debian.org/cdimage/release/
          http://cdimage.debian.org/cdimage/archive/
          http://cdimage.debian.org/cdimage/openstack/
          http://cdimage.debian.org/cdimage/openstack/archive/
          http://releases.ubuntu.com/
          http://old-releases.ubuntu.com/releases/
          http://cdimage.ubuntu.com/
          https://files.devuan.org/

Examples: 9.9.0:i386 debian-10.2.0 debian-daily debian-weekly debian-openstack-11
          ubuntu-18.04.1 kubuntu-18.04.1 ubuntu-server-18.04.1
          devuan-jessie-1.0.0 devuan-ascii-2.0.0 devuan-ascii-2.1
Version? '
[ -n "$DEST" ] || read -p "$EX" DEST || exit

########################################################################
########################################################################
## Find source
########################################################################
########################################################################

VERS="${DEST%:*}"
DEST="${DEST#"$VERS"}"
ARCH="${DEST#:}"
ARCH="${ARCH:-amd64}"

VERS="${VERS%":$ARCH"}"
BRAND="${VERS%%[0-9]*}"
VERS="${VERS#"$BRAND"}"

BRAND="${BRAND%-}"

release=release
case "$VERS" in
*-beta)	release=beta;;
esac

NOTE=()
case "$BRAND" in
(''|debian)		BASE=(
				"http://cdimage.debian.org/cdimage/release/%s/$ARCH/iso-cd/debian-%s-$ARCH-netinst.iso"
				"http://cdimage.debian.org/cdimage/archive/%s/$ARCH/iso-cd/debian-%s-$ARCH-netinst.iso"
				"https://cdimage.debian.org/mirror/cdimage/archive/%s/$ARCH/jigdo-cd/debian-%s-$ARCH-netinst.jigdo"
			)
			BRAND=debian
			;;
(debian-openstack)	BASE=(
				"http://cdimage.debian.org/cdimage/openstack/current-%s/debian-%s-openstack-${ARCH}.qcow2"
				"http://cdimage.debian.org/cdimage/openstack/archive/%s/debian-%s-openstack-${ARCH}.qcow2"
			)
			BRAND=debian-openstack
			;;
(debian-archive)	BASE=(	# now redundant
				"http://cdimage.debian.org/cdimage/archive/%s/$ARCH/iso-cd/debian-%s-$ARCH-netinst.iso"
			)
			BRAND=debian
			;;
(debian-weekly)		BASE=(
				"https://cdimage.debian.org/cdimage/weekly-builds/$ARCH/iso-cd/debian-testing-$ARCH-netinst.iso"
			)
			VERS="$(date +%Y.%V)"
			;;
(debian-daily)		BASE=(
				"https://cdimage.debian.org/cdimage/daily-builds/daily/current/$ARCH/iso-cd/debian-testing-$ARCH-netinst.iso"
			)
			VERS="$(date +%Y.%m.%d)"
			;;
(ubuntu)		BASE=(
				"http://releases.ubuntu.com/%s/ubuntu-%s-desktop-$ARCH.iso"
				"http://old-releases.ubuntu.com/releases/%s/ubuntu-%s-desktop-$ARCH.iso"
			)
			;;
(*buntu)		BASE=(
				"http://cdimage.ubuntu.com/$BRAND/releases/%s/$release/$BRAND-%s-desktop-$ARCH.iso"
			)
			;;
(ubuntu-*server)	VARIANT="${BRAND#*-}"
			BASE=(
				"http://releases.ubuntu.com/%s/ubuntu-%s-$VARIANT-$ARCH.iso"
				"http://cdimage.ubuntu.com/ubuntu/releases/%s/$release/ubuntu-%s-$VARIANT-$ARCH.iso"
				"http://old-releases.ubuntu.com/releases/%s/ubuntu-%s-$VARIANT-$ARCH.iso"
			)
			# WTF why is this shit needed since 20.04?
			case "$VARIANT-$VERS" in
			(server-2*)
				NOTE=(	""
					"Hint: Try ubuntu-live-server"
					"For unknown reason, ubuntu-server is missing for 20.x and later"
					"");;
			esac
			;;
# found no way to automate ubuntu-daily, as this has no stable codename

# This currently only allows to download the netinstall variant of Devuan
# as files.devuan.org is far too volatile for my taste.
# Sadly, Devuan is not autodetectable either, so you must give
# devuan-jessie-1.0.0
# devuan-ascii-2.0.0
# devuan-ascii-2.1
# devuan-beowulf-3.1.1
# I really have no idea what happened to ISOs of 3.0.0 and 3.1.0.
# Also: They seem to rename the netinstall.iso for EACH release.
# And they renamed the "old" sub-folder into some top level "archive" folder.
(devuan-*)		# WTF are they doing there?
			BASE=(
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_netinstall.iso"	# 3.1.1
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_netinst.iso"	# 2.1
				"https://files.devuan.org/archive/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_netinst.iso" # 2.0.0
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_NETINST.iso"	# 1.0.0
			)
			;;
(*)			OOPS "unknown brand: $BRAND for version $VERS";;
esac

MD5SUMS=y
SHA1SUMS=y
SHA256SUMS=y
SHA512SUMS=y

case "$BRAND" in
debian*)	KEYS=debian-role-keys.gpg
		SIGS=sign
		MD5SUMS=n		# WTF why?  suddenly those disappeared
		SHA1SUMS=n		# WTF why?  suddenly those disappeared
		;;
*buntu*)	KEYS=ubuntu-archive-keyring.gpg
		SIGS=gpg
		SHA512SUMS=n
		MD5SUMS=n		# WTF why?  suddenly those disappeared
		SHA1SUMS=n		# WTF why?  suddenly those disappeared
		;;
(devuan*)	KEYS=devuan-devs.gpg
		SIGS=asc
		MD5SUMS=n
		SHA1SUMS=n
		SHA512SUMS=n
		;;
(*)		OOPS "unknown brand: $BRAND for version $VERS";;
esac

FIXVERS="$VERS"
case "$BRAND:$VERS" in
(debian:[1-5].*)	FIXVERS="${VERS//[._]/}";;
(*buntu*:*-beta)	FIXVERS="$VERS"; VERS="${VERS%-beta}";;
esac

case "$VERS" in
(*[^0-9._r]*)	OOPS "Huh? Version is $VERS";;
([1-4].[0-9]_r[0-9])	;;
(*[^0-9.]*)	OOPS "Huh? Version is $VERS";;
([0-9]*.*[0-9])	;;
(*[^0-9]*)	OOPS "Huh? Version is $VERS";;
([0-9]*)	;;
(*)		OOPS "Huh? Version is $VERS";;
esac

########################################################################
########################################################################
## Prepare working environment
########################################################################
########################################################################

o cd "$(dirname -- "$0")"
HERE="$PWD"
[ -d ISO ] || OOPS "Directory ISO/ does not exist." "Try: mkdir '$HERE/ISO'" "or:  ln -Tsr \"\$PATH_WHERE_ISOS_SHALL_BE_LINKED_TO\" '$HERE/ISO'"
o mkdir -pm755 DATA ISO

DIR="$BRAND-$VERS:$ARCH"

RINGS=()
for a in /usr/share/keyrings /usr/local/share/keyrings /etc/keyring* "$HOME/.keyrings" "$HOME/.gnupg" keyrings/* "keyrings/.$DIR"
do
	for b in "$a"/*.gpg
	do
		[ -s "$b" ] && RINGS+=("$(readlink -e -- "$b")")
	done
done

HINT="cd '$HERE' && git submodule update --init"
[ -d keyrings/hilbix ] && HINT="'$HERE/keyrings/hilbix/find.sh' '$HERE/DATA/$DIR'"
[ -d "keyrings/hilbix/$DIR" ] && HINT="ln -s 'hilbix/$DIR' '$HERE/keyrings/.$DIR'"

[ -d "DATA/$DIR" ] || o mkdir "DATA/$DIR"
o pushd "DATA/$DIR" >/dev/null;

SUMS=()
for a in MD5SUMS SHA1SUMS SHA256SUMS SHA512SUMS
do
	[ n = "${!a}" ] || SUMS+=("$a")
done

[ -s "$HOME/.proxy.conf" ] && . "$HOME/.proxy.conf"

########################################################################
########################################################################
## Helper routines
########################################################################
########################################################################

# /bin/cp is completely borken as well.
#
# It contains a bug, that certain files with a read error at position 0
# are reported SUCCESSFULLY COPIED with 0 bytes even if the copy failed.
# EOF is not verified by /bin/cp and, thanks to POSIX, kernels are allowed
# to return EOF instead of write errors at certain poings.  cp falls into this trap.
# Another problem is, that you cannot prevent it to copy softlinks as softlinks these days.
# But the probably most annoying thing is what happens if cp is interrupted
# (always think of a sudden power outage) which leaves us clueless with all pieces.
#
# So always first copy to a TMP file and then do some atomic replace.
# For a sane implementation of copy, I expect that it does a "cmp" first,
# hence skip writes (which might degrade an SSD) if all possible.
#
# Following is not a correct implementation.  But it suffices here.
safecp()
{
  x cmp -s -- "$1" "$2" && return;	# first: compare
  printf 'copying existing %q\n' "$2"
  x rm -f -- "$2.tmp";			# Use tmpfile here.  I am lazy as this is ok here
  o cp -f -- "$1" "$2.tmp";		# copy to tmpfile
  o mv -f -- "$2.tmp" "$2";		# hopefully this does an atomical rename()
}

# WGET is a complete desaster in case it is interrupted for some reason
# Like power outage, kill or ^C.
# Hence we are not allowed to write things directly into the directory.
# Why are standard tools always constructed such badly that they do
# maximum harm in case something does not work as expected, instead
# being done conservatively, such that they never cause grieve?
#
# Why not use "curl"?  jigdo uses wget.
# So we already have wget while curl is not neccessarily installed.
#
# Note that this also exposes an wget bug:
# -N does not work as advertised.
# We have a successful download,
# and wget tells
#	The file is already fully retrieved; nothing to do.
# but forgets to update the file's timestamp.
# Hello?  Anybody out there?  Any intelligent being?
#
# I leave it as-is.
# Sorry for the ancient timestamps then
# if you download it a second time.
# Not my fault.
download()
{
local FILE="${1##*/}"

# Do the download in a temporary folder
[ -d tmp ] || mkdir tmp;
o pushd tmp >/dev/null;

# Take advantage of some existing file.
#
# What we want is to:
# - Detect, if a download is present or not
# - Send "range" requests to continue borken downloads
# - Use timestamps of the server
# - And do not download anything when everything already is in place
# (So the most useful and common application of a download.)
# Hence we need -c and -N.
#
# But option -N is a complete desaster in wget,
# as this is not doing timestamping alone, it does timestamp checking, too.
# Something we definitively do not want.  Ever!
#
# Due to this grave misimplementation (doing to things in combination instead of only a single thing),
# we cannot use -r nor --no-if-modified-since (we do not want HEAD) nor -O either.
# WTF!?! This is not only a PITA, this is plain shit!
#
# BTW: I refer to documentation here.  If documentation says, it does HEAD, but it doesn't,
# I really have no idea what future brings.  I always use documentation first, implement second.
# Hence if documentation is wrong I must assume that implementation is or becomes wrong, too.
# And if implementation is right, this is just an accident.
#
# So better be safe than sorry and work around all bugs, regardless if they are in documentation or implementation.
# Read: Use some way that just works and contains all desireable properties (see above).
#
# If wget would have been implemented properly from the beginning
# we do not need all this copying around here
# nor the need to re-invent a wheel with 2 additional corners.
[ -s "../$FILE" ] && [ ! -s "$FILE" ] && o safecp "../$FILE" "$FILE";

# Timezone is something similar.  Why doesn't everything rely on UTC first
# and only some obscure presentation layer transfers this into local time?
# As it DOES rely on UTC internally, but tools do not expose that, causing
# a lot of grief over the last and all coming centuries!
#
# Touch existing file into the stone age to make wget -Nc work
[ -f "$FILE" ] && TZ=UTC o touch -t 198001010000 "$FILE";

"$WGET" -N -c -- "$1" &&
o mv -f "$FILE" ..;		# file successfully downloaded and timestamped

i o popd >/dev/null;
# It is expected that some things stay in tmp, like jigdo things.
i x rmdir tmp 2>/dev/null;

# FYI this here has return value of wget, see "i" above
}

# URL="$SUB/$DAT" but see jigdo() below
findbase()
{
LOOK=()
for try in "${BASE[@]}"
do
	case "$try" in
	(*%s*%s*)	o printf -v URL "$try" "$VERS" "$FIXVERS";;
	(*%s*)		o printf -v URL "$try" "$VERS";;
	(*)		URL="$try";;
	esac

	SUB="${URL%/*}"
	DAT="${URL##*/}"
	#echo "$BRAND -- $ARCH -- $VERS -- $FIXVERS - $URL"; exit 1

	LOOK+=("$URL")
	download "$URL" && return
done
OOPS "Download missing, tried ${LOOK[*]}" "${NOTE[@]}"
}

# URL="$SUB/${DAT%.iso}.jigdo" iff using jigdo
# so DAT is the .iso
# and URL is the jigdo URL
jigdo()
{
local JIG="$DAT"

case "$DAT" in
(*.jigdo)	;;
(*)		return;;
esac

DAT="${DAT%.jigdo}.iso"
[ -s "$DAT" ] && o printf 'using existing file %q\n' "$DAT" && return;

get JIGDO jigdo-lite jigdo-file

[ -d tmp ] || mkdir tmp;
o pushd tmp >/dev/null;
o safecp "../$JIG" "$JIG";	# do not re-download .jigdo

# What can possibly go wrong here when using jigdo?
#
# jigdo is able to recover if someting goes wrong, right?
# Wrong!  jigdo --noask enters an ENDLESS LOOP in case
# /etc/apt/sources.list is empty or missing
# and no ~/.jigdo-lite is present, to.
# Well done, folks, BCP on system level makes breaks userland tools.
#
# Sadly, I cannot do anything about that except leaving away --noask,
# but we definitively do not want to run without.  Shit in, shit out.
#
# Sadly, --scan cannot be used as this needs a MOUNTED .iso.  WTF WHY?
# We are able to CREATE some image but are not able to REUSE it?
# (Note that rsync supports such scans, why not jigdo?)
#
# Also, in case the $DAT is already present, we need to remove it here.
# As jigdo-lite has no way to give --force to jigdo-file by chance.
# (it can be hacked into ~/.jigdo-lite, but this is not a valid offer.)
o rm -f "$DAT"
o "$JIGDO" --noask "$URL"
o mv -f "$DAT" ..

o popd >/dev/null;
x rmdir tmp 2>/dev/null;
}

# Remove Naziisms from GPG
# and add a brain to escape all those GPG defects.
#
# How unusable can a software possibly be written?
# And the winner is .. gpg!
# It's even far worse than OpenSSL!
# Do they ever use their own piece of software for some real thing?
# Or was it just written to drive people away from Crypto?
# For the latter:  It does a very effective job!  Yay!
denazify-and-add-a-brain-to-gpg-verify()
{
local murx ring

# As GPG crashes on the first minimal thing, we cannot give it a list of keyrings.
# So we have to use a tiny loop here.
for ring in "${RINGS[@]}";
do
	murx="$(LC_ALL=C.UTF-8 "$GPG" --no-default-keyring --keyring "$ring" --verify "$1" 2>&1)" || continue;

	echo "$murx" |

	# Nope, we do not want to hear any racial propaganda
	grep -v "^gpg: assuming signed data in '[^']*'\$" |

	# Nope, I am also not interested on obscure historic evidence made up
	grep -v '^gpg: Signature made ' |

	# Nope, and leave me alone with any ethnical statements, too
	grep -v '^gpg:                using [RD]SA key [0-9A-F]*$' |

	# Nope, also please leave me alone with your trust in being the only worthy superrace
	grep -v '^gpg: WARNING: This key is not certified with a trusted signature!' |

	# Nope, and please do not even think about blaming the Jews!
	grep -v '^gpg:          There is no indication that the signature belongs to the owner.' |

	# Nope, I really cannot stand anymore to hear you talking about right and order!
	grep -v '^Primary key fingerprint: [0-9A-F ]*$' |

	# Instead, we want to live long and prosper
	grep '[^[:space:]]'

	return
done
return 1;
}

check()
{
local res dat checker

[ n = "${!1}" ] && return

o v dat awk -vX="$DAT" '$2 == X { print }' "$1"
[ -n "$dat" ] || OOPS "$1 does not contain checksum for $DAT"
get checker "$2" coreutils
printf 'chk %s\r' "$1"
x v res "$checker" --check --strict <<<"$dat" &&
printf '%12s: %s\n' "$1" "$res" &&
case "$res" in
(*": OK")	return;;
esac
OOPS "$1 mismatch" "(perhaps remove $PWD and try again)"
}

########################################################################
########################################################################
## Now do the real work
########################################################################
########################################################################

# Download
findbase
jigdo
for a in "${SUMS[@]}" "${SUMS[@]/%/.$SIGS}"
do
	[ -s "$a" ] && o printf 'using existing file instead of %q\n' "$SUB/$a" || download "$SUB/$a"
done

# Verify checksums are authentic (signed)
# See https://stackoverflow.com/a/35820272
for a in "${SUMS[@]}"
do
	printf '%12s: ' "$a"
	[ sign = "$SIGS" ] || [ -L "$a.sign" ] || o ln -s "$a.$SIGS" "$a.sign"
	( o denazify-and-add-a-brain-to-gpg-verify "$a.sign" ) ||
	OOPS "verify failure for $a - the missing key is probably named $KEYS" "try to find the right key and copy it to $HERE/keyrings/.$DIR/" "or, if you trust me and the git repo and the key happens to be there:" "$HINT"
done

# Verify download with checkusm
check MD5SUMS		md5sum
check SHA1SUMS		sha1sum
check SHA256SUMS	sha256sum
check SHA512SUMS	sha512sum

# Create predictable easy to use softlinks
SHORT="${BASE##*/}"
SHORT="${SHORT//_/-}"
ln -vfs "$DAT" "${SHORT//-%s-/-}"

o popd >/dev/null
o printf -v RIGHT "$SHORT" "$VERS"
o rm -vf "ISO/$RIGHT"
ln -vfs --relative "DATA/$DIR/$DAT" "ISO/$RIGHT"

