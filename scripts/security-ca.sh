#!/bin/sh
# Rebuild OS trust; remove G3/AAA roots and reject eight compromised SPKIs.
# Optional root is for isolated fixtures only; never run this on a workstation root.
set -eu
root=${1:-/}
root=${root%/}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
spki() {
  openssl x509 -in "$1" -pubkey -noout > "$work/public.pem" || exit 1
  openssl pkey -pubin -in "$work/public.pem" -outform DER > "$work/public.der" || exit 1
  result=$(openssl dgst -sha256 "$work/public.der")
  printf '%s\n' "${result##* }"
}
blocked() {
  case "$1" in
    ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105|49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f|e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41|5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0|43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b|63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8|ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6|92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30) return 0 ;;
    *) return 1 ;;
  esac
}
rejected_certificate() {
  fingerprint=$(spki "$1") || exit 1
  if blocked "$fingerprint"; then return 0; fi
  openssl x509 -in "$1" -outform DER > "$work/certificate.der" || exit 1
  result=$(openssl dgst -sha256 "$work/certificate.der")
  case "${result##* }" in
    86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b|d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4) return 0 ;;
    *) return 1 ;;
  esac
}
for directory in "$root/usr/share/ca-certificates" "$root/usr/local/share/ca-certificates"; do
  [ -d "$directory" ] || continue
  find "$directory" -type f -name '*.crt' > "$work/files"
  while IFS= read -r certificate; do
    if rejected_certificate "$certificate"; then rm -f "$certificate"; fi
  done < "$work/files"
done
if [ -z "$root" ]; then
  update-ca-certificates --fresh
else
  # Fixture mode cannot run the host's trust-store updater.
  mkdir -p "$root/etc/ssl/certs"
  : > "$root/etc/ssl/certs/ca-certificates.crt"
  for directory in "$root/usr/share/ca-certificates" "$root/usr/local/share/ca-certificates"; do
    [ -d "$directory" ] || continue
    find "$directory" -type f -name '*.crt' > "$work/files"
    while IFS= read -r certificate; do cat "$certificate" >> "$root/etc/ssl/certs/ca-certificates.crt"; done < "$work/files"
  done
fi
bundle="$root/etc/ssl/certs/ca-certificates.crt"
[ -s "$bundle" ]
awk -v directory="$work" '/-----BEGIN CERTIFICATE-----/ {number++; file=directory "/verify-" number ".pem"} file {print > file} /-----END CERTIFICATE-----/ {close(file); file=""}' "$bundle"
count=0
for certificate in "$work"/verify-*.pem; do
  [ -f "$certificate" ] || continue
  count=$((count + 1))
  if rejected_certificate "$certificate"; then echo 'Rejected SPKI remained in the OS trust bundle' >&2; exit 1; fi
done
[ "$count" -gt 0 ]
printf 'Verified CA trust bundle: %s certificates; compromised SPKIs absent\n' "$count"
