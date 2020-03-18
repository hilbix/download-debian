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

OOPS() { echo "$*" >&2; exit 23; }
o() { "$@" || OOPS "exec $?: $*"; }
v() { local -n __var__="$1"; __var__="$("${@:2}")" || OOPS "exec $?: $*"; }

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

VERS="${DEST%:*}"
DEST="${DEST#"$VERS"}"
ARCH="${DEST#:}"
ARCH="${ARCH:-amd64}"

VERS="${VERS%":$ARCH"}"
BRAND="${VERS%%[0-9]*}"
VERS="${VERS#"$BRAND"}"

BRAND="${BRAND%-}"

OLDBASE=
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
				"http://cdimage.ubuntu.com/$BRAND/releases/%s/release/$BRAND-%s-desktop-$ARCH.iso"
			)
			;;
(ubuntu-server)		BASE=(
				"http://cdimage.ubuntu.com/ubuntu/releases/%s/release/ubuntu-%s-server-$ARCH.iso"
				"http://old-releases.ubuntu.com/releases/%s/ubuntu-%s-server-$ARCH.iso"
			)
			;;
# found no way to automate ubuntu-daily, as this has no stable codename
# sadly, devuan is not autodetectable either, so you must give
# devuan-jessie-1.0.0 or devuan-ascii-2.0.0
(devuan-*)		# WTF are they doing there?
			BASE=(
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_netinst.iso"
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/${BRAND/-/_}_%s_${ARCH}_NETINST.iso"
				"https://files.devuan.org/${BRAND/-/_}/installer-iso/old/${BRAND/-/_}_%s_${ARCH}_netinst.iso"
			)
			BRAND=devuan
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
		;;
(devuan)	KEYS=devuan-devs.gpg
		SIGS=asc
		MD5SUMS=n
		SHA1SUMS=n
		SHA512SUMS=n
		;;
(*)		OOPS "unknown brand: $BRAND for version $VERS";;
esac

case "$VERS" in
(*[^0-9._r]*)	OOPS "Huh? Version is $VERS";;
([1-4].[0-9]_r[0-9])	;;
(*[^0-9.]*)	OOPS "Huh? Version is $VERS";;
([0-9]*.*[0-9])	;;
(*)		OOPS "Huh? Version is $VERS";;
esac

for a in "/usr/share/keyrings/$KEYS" "/usr/local/share/keyrings/$KEYS" "/etc/keyring/$KEYS" "$HOME/.keyrings/$KEYS" "$HOME/.gnupg/$KEYS" keyrings/*/"$KEYS"
do
	[ -s "$a" ] && KEYS="$(readlink -e -- "$a")"
done

# try: apt-get install debian-keyring ubuntu-keyring devuan-keyring
[ -f "$KEYS" ] || OOPS missing file: "$KEYS"

FIXVERS="$VERS"
case "$BRAND:$VERS" in
(debian:[1-5].*)	FIXVERS="${VERS//[._]/}";;
esac

o cd "$(dirname -- "$0")"
o mkdir -pm755 DATA ISO

DIR="$BRAND-$VERS:$ARCH"

[ -d "DATA/$DIR" ] || o mkdir "DATA/$DIR"
o pushd "DATA/$DIR"

SUMS=()
for a in MD5SUMS SHA1SUMS SHA256SUMS SHA512SUMS
do
	[ n = "${!a}" ] || SUMS+=("$a")
done

[ -s "$HOME/.proxy.conf" ] && . "$HOME/.proxy.conf"

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
	case "$DAT" in (*.jigdo) DAT="${DAT%.jigdo}.iso";; esac	# jigdo-hack
	#echo "$BRAND -- $ARCH -- $VERS -- $FIXVERS - $URL"; exit 1

	LOOK+=("$URL")
	wget -N -- "$URL" && return
done
OOPS "Download missing, tried ${LOOK[*]}"
}

findbase
for a in "${SUMS[@]}" "${SUMS[@]/%/.$SIGS}"
do
	wget -N -- "$SUB/$a"
done

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
grep -v '^gpg:                using RSA key [0-9A-F]*$' |

# Nope, also please leave me alone with your trust in being the only worthy superrace
grep -v '^gpg: WARNING: This key is not certified with a trusted signature!' |

# Nope, and please do not even think about blaming the Jews!
grep -v '^gpg:          There is no indication that the signature belongs to the owner.' |

# Nope, I really cannot stand anymore to hear you talking about right and order!
grep -v '^Primary key fingerprint: [0-9A-F ]*$' |

# Instead, we want to live long and prosper
grep '[^[:space:]]'
}

# See https://stackoverflow.com/a/35820272
for a in "${SUMS[@]}"
do
	printf '%12s: ' "$a"
	[ sign = "$SIGS" ] || [ -L "$a.sign" ] || o ln -s "$a.$SIGS" "$a.sign"
	o denazify gpg --no-default-keyring --keyring "$KEYS" --verify "$a.sign"
done

check()
{
[ n = "${!1}" ] && return

v x "$2" --check --strict <(fgrep "$DAT" "$1")
printf '%12s: %s\n' "$1" "$x"
case "$x" in
(*": OK")	return;;
esac
OOPS "$1 fail"
}

check MD5SUMS		md5sum
check SHA1SUMS		sha1sum
check SHA256SUMS	sha256sum
check SHA512SUMS	sha512sum

SHORT="${BASE##*/}"
ln -vfs "$DAT" "${SHORT//-%s-/-}"

o popd >/dev/null
o printf -v RIGHT "$SHORT" "$VERS"
o rm -vf "ISO/$RIGHT"
ln -vfs --relative "DATA/$DIR/$DAT" "ISO/$RIGHT"

