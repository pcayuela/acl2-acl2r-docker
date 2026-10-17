#!/usr/bin/env bash
# Smoke-test both executables in the image: load certified books and prove one
# theorem each. Usage: ./test.sh [image]
set -euo pipefail
IMG="${1:-acl2-pcayuela}"
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sg docker -c); fi
run() {
  if [ "${DOCKER[0]}" = docker ]; then docker run --rm -i "$IMG" "$@"
  else sg docker -c "docker run --rm -i $IMG $*"; fi
}

echo "== plain ACL2 =="
out=$(run acl2 <<'LISP'
(include-book "arithmetic-5/top" :dir :system)
(defthm t1 (equal (+ x y) (+ y x)))
LISP
)
echo "$out" | grep -q "Q.E.D." || { echo "$out"; echo "FAIL plain"; exit 1; }
echo "$out" | grep -q 'books/arithmetic-5/top.lisp' && echo "ok: arithmetic-5/top loaded, no recertification"

echo "== ACL2(r) =="
out=$(run acl2r <<'LISP'
(include-book "nonstd/nsa/trig" :dir :system)
(include-book "nonstd/workshops/2011/reid-gamboa-differentiator/support/differentiator" :dir :system)
(defthm t2 (implies (realp x) (equal (+ x 0) x)))
LISP
)
echo "$out" | grep -q "Q.E.D." || { echo "$out"; echo "FAIL real"; exit 1; }
echo "$out" | grep -q 'ACL2(r)' && echo "ok: ACL2(r) with nonstd books loaded"
echo "ALL OK"
