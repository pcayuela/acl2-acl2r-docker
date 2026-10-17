#!/usr/bin/env bash
# Recertify an ACL2 / ACL2(r) project from clean sources inside the image.
#
#   ./verify-project.sh <project-dir> <plain|real> <top-book> [image]
#
# Only the *.lisp / *.acl2 / *.lsp files are copied to a temporary directory
# (existing .cert files are NOT used), then `cert.pl <top-book>` runs inside the
# container.  The project directory itself is never modified.
set -euo pipefail
proj="${1:?project directory}"; flavor="${2:?plain|real}"; top="${3:?top book (no .lisp)}"
IMG="${4:-ghcr.io/pcayuela/acl2-acl2r-docker:8.7}"
case "$flavor" in
  plain) acl2=/opt/acl2/saved_acl2;  certpl=/opt/acl2/books/build/cert.pl; want="ACL2 Version 8.7" ;;
  real)  acl2=/opt/acl2r/saved_acl2r; certpl=/opt/acl2r/books/build/cert.pl; want="ACL2 Version 8.7(r)" ;;
  *) echo "flavor must be plain or real" >&2; exit 2 ;;
esac
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
( cd "$proj" && find . -maxdepth 1 -type f \( -name '*.lisp' -o -name '*.acl2' -o -name '*.lsp' \) -exec cp {} "$tmp"/ \; )
chmod -R a+rwx "$tmp"
D=docker; docker info >/dev/null 2>&1 || D="sg docker -c"
run="$certpl --acl2 $acl2 -j $(nproc) $top"
if [ "$D" = docker ]; then
  docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$tmp":"$tmp" -w "$tmp" "$IMG" bash -c "$run"
else
  sg docker -c "docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -v '$tmp':'$tmp' -w '$tmp' $IMG bash -c '$run'"
fi
got="$(head -c 400 "$tmp/$top.cert" | grep -a -o 'ACL2 Version [0-9.()r]*' | head -1)"
[ "$got" = "$want" ] || { echo "FAIL: certificate says '$got', expected '$want'"; exit 1; }
echo "OK: $top certified from clean sources ($got)"
