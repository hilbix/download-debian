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
          http://releases.ubuntu.com/
          http://old-releases.ubuntu.com/releases/
          http://cdimage.ubuntu.com/
          https://files.devuan.org/

Examples: 9.9.0:i386 debian-10.2.0 debian-daily debian-weekly
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
		[ -s "$b" ] && RINGS+=(--keyring "$(readlink -e -- "$b")")
	done
done

HINT="cd '$HERE' && git submodule update --init"
[ -d keyrings/hilbix ] && HINT="'$HERE/keyrings/hilbix/find.sh' '$HERE/DATA/$DIR'"
[ -d "keyrings/hilbix/$DIR" ] && HINT="ln -s 'hilbix/$DIR' '$HERE/keyrings/.$DIR'"

[ -d "DATA/$DIR" ] || o mkdir "DATA/$DIR"
o pushd "DATA/$DIR"

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
	"$WGET" -N -- "$URL" && return
done
OOPS "Download missing, tried ${LOOK[*]}" "${NOTE[@]}"
}

# URL="$SUB/${DAT%.iso}.jigdo" iff using jigdo
# so DAT is the .iso
# and URL is the jigdo URL
jigdo()
{
case "$DAT" in
(*.jigdo)	;;
(*)		return;;
esac

DAT="${DAT%.jigdo}.iso"
[ -s "$DAT" ] && return

get JIGDO jigdo-lite jigdo-file
o "$JIGDO" --noask "$URL"
}

# Remove Naziisms from GPG
denazify()
{
local murx

murx="$(LC_ALL=C.UTF-8 "$@" 2>&1)" || { local e=$?; echo "$murx"; return $e; }

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
}

check()
{
[ n = "${!1}" ] && return

v d fgrep "$DAT" "$1"
get checker "$2" coreutils
printf 'chk %s\r' "$1"
v x "$checker" --check --strict <<<"$d"
printf '%12s: %s\n' "$1" "$x"
case "$x" in
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
	"$WGET" -N -- "$SUB/$a"
done

# Verify checksums are authentic (signed)
# See https://stackoverflow.com/a/35820272
for a in "${SUMS[@]}"
do
	printf '%12s: ' "$a"
	[ sign = "$SIGS" ] || [ -L "$a.sign" ] || o ln -s "$a.$SIGS" "$a.sign"
	( o denazify "$GPG" --no-default-keyring "${RINGS[@]}" --verify "$a.sign" ) ||
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

