#!/bin/bash
set -e

STORAGE_DIR="/opt/wg-easy"

echo "Creating storage directory at $STORAGE_DIR..."
sudo mkdir -p "$STORAGE_DIR"

echo "Setting SELinux labels for container access..."
# The :Z flag in podman run handles this, but we'll pre-set it for robustness
sudo semanage fcontext -a -t container_file_t "$STORAGE_DIR(/.*)?" || true
sudo restorecon -Rv "$STORAGE_DIR"

echo "Storage setup complete."
