#!/usr/bin/env bash

# Exit immediately on errors, treat unset vars as errors, and fail on pipeline errors
set -euo pipefail

# 1️⃣ Backup your apt sources
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M)
sudo cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.backup.$(date +%Y%m%d%H%M)

# 2️⃣ List all Noble entries to confirm what needs disabling
grep -R "noble" -n /etc/apt/sources.list /etc/apt/sources.list.d || true

# 3️⃣ Disable all Noble PPAs/sources
if grep -q "noble" /etc/apt/sources.list; then
  sudo cp /etc/apt/sources.list /etc/apt/sources.list.noble-backup.$(date +%Y%m%d%H%M)
  sudo sed -i '/noble/s/^/# /' /etc/apt/sources.list
fi
sudo bash -c 'grep -Rl "noble" /etc/apt/sources.list.d | xargs -r -I{} mv {} {}.disabled'

# 4️⃣ Remove Deadsnakes PPA (if it exists)
sudo add-apt-repository --remove ppa:deadsnakes/ppa || true

# 5️⃣ Update apt metadata to reflect Jammy-only repos
sudo apt-get update

# 6️⃣ Unhold Python packages to allow reinstall
sudo apt-mark unhold python3.10 python3.10-minimal libpython3.10 libpython3.10-minimal libpython3.10-stdlib 2>/dev/null || true

# 7️⃣ Check the Jammy candidate version for python3.10
python_candidate=$(apt-cache policy python3.10 | awk '/Candidate:/ {print $2}')
if [[ -z "${python_candidate}" || "${python_candidate}" == "(none)" ]]; then
  echo "Unable to determine the python3.10 candidate version from Jammy repositories. Aborting." >&2
  exit 1
fi
echo "Detected python3.10 candidate version: ${python_candidate}"

# 8️⃣ Reinstall Jammy-compatible Python 3.10 packages
sudo apt-get install --reinstall \
  python3.10="${python_candidate}" \
  python3.10-minimal="${python_candidate}" \
  libpython3.10="${python_candidate}" \
  libpython3.10-minimal="${python_candidate}" \
  libpython3.10-stdlib="${python_candidate}"

# 9️⃣ Fix any remaining broken dependencies
sudo apt-get -f install

# 🔟 Upgrade all packages to latest Jammy versions
sudo apt-get dist-upgrade -y

# 1️⃣1️⃣ Remove unnecessary packages pulled in by Noble
sudo apt-get autoremove --purge -y

# 1️⃣2️⃣ Now the system is clean; run the release upgrade
sudo do-release-upgrade
