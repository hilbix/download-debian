#!/bin/bash

VERS="$1"

OOPS() { echo "$*" >&2; exit 23; }
o() { "$@" || OOPS "exec $?: $*"; }
v() { local -n __var__="$1"; __var__="$("${@:2}")" || OOPS "exec $?: $*"; }

[ -n "$VERS" ] || read -p 'Version (like: 9.3.0): ' VERS || exit

BRAND="$VERS"
VERS="${VERS#[a-z]*-}"
BRAND="${BRAND%"$VERS"}"
BRAND="${BRAND%-}"
case "$BRAND" in
(''|debian)		SIGS=sign
			BRAND=debian
			BASE="http://cdimage.debian.org/debian-cd/%s/amd64/iso-cd/debian-%s-amd64-netinst.iso"
			SHA512=y
			KEYS=/usr/share/keyrings/debian-role-keys.gpg
			;;
(*ubuntu)		SIGS=gpg
			BASE="http://cdimage.ubuntu.com/$BRAND/releases/%s/release/$BRAND-%s-desktop-amd64.iso"
			SHA512=n
			KEYS=/usr/share/keyrings/ubuntu-archive-keyring.gpg
			;;
(*)			OOPS "unknown brand: $BRAND for version $VERS";;
esac

case "$VERS" in
*[^0-9.]*)	OOPS "Huh? Version is $VERS";;
[0-9]*.*[0-9])	;;
*)		OOPS "Huh? Version is $VERS";;
esac

[ -f "$KEYS" ] || OOPS missing file: "$KEYS"

o printf -v URL "$BASE" "$VERS" "$VERS"

[ -d "$BRAND-$VERS" ] || o mkdir "$BRAND-$VERS"
o cd "$BRAND-$VERS"

SUB="${URL%/*}"
DAT="${URL##*/}"
SUMS=(MD5SUMS SHA1SUMS SHA256SUMS)
[ n = "$SHA512" ] || SUMS+=(SHA512SUMS)

[ -s ~/.prox ] &&
. ~/.prox

for a in "$DAT" "${SUMS[@]}" "${SUMS[@]/%/.$SIGS}"
do
	[ -s "$a" ] && continue
	wget -- "$SUB/$a"
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
[ n = "$SHA512" ] ||
check SHA512SUMS	sha512sum

