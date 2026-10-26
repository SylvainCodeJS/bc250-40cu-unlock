#!/usr/bin/env bash
# bc250-40cu-rebuild.sh — reconstruit et installe l'amdgpu patché 40 CU pour
# chaque noyau CachyOS présent (mainline et -lts) qui ne l'a pas déjà.
# Appelé automatiquement par le hook pacman après mise à jour d'un noyau
# CachyOS (voir ../packaging/95-bc250-40cu-rebuild.hook).
#
# Installation :
#   sudo install -Dm755 bc250-40cu-rebuild.sh /usr/local/bin/bc250-40cu-rebuild.sh
#   sudo install -Dm755 bc250-enable-40cu-arch.sh /usr/local/bin/bc250-enable-40cu-arch.sh
#   sudo install -Dm644 ../packaging/95-bc250-40cu-rebuild.hook /etc/pacman.d/hooks/95-bc250-40cu-rebuild.hook
set -uo pipefail

BUILDER=/usr/local/bin/bc250-enable-40cu-arch.sh
LOG_TAG="bc250-40cu-rebuild"

log() { logger -t "$LOG_TAG" "$*"; printf '[%s] %s\n' "$LOG_TAG" "$*" >&2; }

if [ ! -x "$BUILDER" ]; then
    log "ERREUR: $BUILDER introuvable ou non exécutable, abandon."
    exit 1
fi

status=0
# Couvre le noyau CachyOS principal (*-cachyos) ET la variante LTS
# (*-cachyos-lts) — les deux paquets réinstallent un amdgpu.ko stock à
# chaque upgrade, donc les deux doivent être repatchés après coup.
for d in /usr/lib/modules/*-cachyos /usr/lib/modules/*-cachyos-lts; do
    [ -d "$d" ] || continue
    kver="$(basename "$d")"
    [ -d "$d/build" ] || { log "pas de headers pour $kver, on saute"; continue; }

    modko="$d/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.zst"
    [ -f "$modko" ] || modko="$d/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"
    [ -f "$modko" ] || { log "pas de module amdgpu pour $kver, on saute"; continue; }

    if zstdcat "$modko" 2>/dev/null | grep -qa 'bc250_cc_write_mode' \
       || grep -qa 'bc250_cc_write_mode' "$modko" 2>/dev/null; then
        log "$kver déjà patché, on saute"
        continue
    fi

    log "reconstruction du module 40 CU pour $kver..."
    if BC250_KVER="$kver" "$BUILDER" build; then
        log "$kver: OK"
    else
        log "$kver: ÉCHEC de la reconstruction"
        status=1
    fi
done

exit "$status"
