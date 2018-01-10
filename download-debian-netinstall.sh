#!/bin/bash

BASE="http://cdimage.debian.org/debian-cd/%s/amd64/iso-cd/debian-%s-amd64-netinst.iso"
VERS="$1"
[ -n "$VERS" ] || read -p 'Version (like: 9.3.0): ' VERS || exit

OOPS() { echo "$*" >&2; exit 23; }
o() { "$@" || OOPS "exec $?: $*"; }
v() { local -n __var__="$1"; __var__="$("${@:2}")" || OOPS "exec $?: $*"; }

case "$VERS" in
*[^0-9.]*)	OOPS "Huh?";;
[0-9]*.*[0-9])	;;
*)		OOPS "Huh?";;
esac

o printf -v URL "$BASE" "$VERS" "$VERS"

[ -d "$VERS" ] || o mkdir "$VERS"
o cd "$VERS"

SUB="${URL%/*}"
DAT="${URL##*/}"
SUMS=(MD5SUMS SHA1SUMS SHA256SUMS SHA512SUMS)

. ~/.prox

for a in "$DAT" "${SUMS[@]}" "${SUMS[@]/%/.sign}"
do
	[ -s "$a" ] && continue
	wget -- "$SUB/$a"
done

# Remove Naziisms from GPG
denazify()
{
local murx

murx="$(LC_ALL=C.UTF-8 "$@" 2>&1)" || return

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
grep -v '^Primary key fingerprint: [0-9A-F ]*$'
}

# See https://stackoverflow.com/a/35820272
for a in "${SUMS[@]}"
do
	printf '%12s: ' "$a"
	o denazify gpg --no-default-keyring --keyring /usr/share/keyrings/debian-role-keys.gpg --verify "$a.sign"
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
check SHA512SUMS	sha512sum
