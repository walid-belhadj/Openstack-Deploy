#!/bin/bash

# Fratelo Kolla-OpenStack Installer Script
# WARNING: Use with caution! Make sure you have backups and are on local console if messing with network/LVM.

# Function to prompt user to continue
confirm() {
    read -p "$1 [y/n/c=continue]: " choice
    case "$choice" in
      y|Y ) echo "Continuing...";;
      n|N ) echo "Installation aborted."; exit 1;;
      c|C ) echo "[INFO] Forced continue..."; break;;
      * ) echo "Invalid choice. Please enter y, n, or c."; ;;
    esac
}

echo "===== Starting Kolla-OpenStack setup ====="

# --------------------------
confirm "Step 1: Update & install packages?"
# First package deployment
sudo apt-get update && echo "[OK] apt-get update done"
sudo apt-get upgrade -y && echo "[OK] apt-get upgrade done"
sudo apt install git python3-dev libffi-dev python3-venv gcc libssl-dev python3-pip python3-full -y && echo "[OK] Required packages installed"

# --------------------------
confirm "Step 2: Set sudo privileges for current user?"
# Privilege
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER
sudo chmod 0440 /etc/sudoers.d/$USER && echo "[OK] sudo privileges configured"

# --------------------------
confirm "Step 3: Set timezone to Paris?"
sudo timedatectl set-timezone Europe/Paris && echo "[OK] Timezone set to Europe/Paris"

# --------------------------
confirm "Step 4: Configure network interfaces?"
# Networking (WARNING: may cut SSH if on these interfaces)
sudo ip addr flush dev enp0s8
sudo ip addr flush dev enp0s9
echo "[OK] Network interfaces reset"

# --------------------------
confirm "Step 5: Create Python virtualenv for Kolla?"
python3 -m venv $HOME/kolla-open && echo "[OK] Virtualenv created"
source $HOME/kolla-open/bin/activate
pip install -U pip && echo "[OK] pip upgraded"
pip install 'ansible>=8,<9' && echo "[OK] Ansible installed"
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2024.1 && echo "[OK] Kolla-Ansible installed"

# --------------------------
confirm "Step 6: Configure ansible and Kolla directories?"
# Folder and file
printf "[defaults]\nhost_key_checking=False\npipelining=True\nforks=100\n" > $HOME/ansible.cfg && echo "[OK] ansible.cfg created"
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r $HOME/kolla-open/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/ && echo "[OK] Kolla config copied"
cp $HOME/kolla-open/share/kolla-ansible/ansible/inventory/all-in-one . && echo "[OK] Inventory copied"

# --------------------------
confirm "Step 7: Copy globals.yml?"
cat $HOME/global.yml > /etc/kolla/globals.yml && echo "[OK] globals.yml copied"

# --------------------------
confirm "Step 8: Create volume for Cinder?"
sudo pvcreate /dev/sdb && echo "[OK] Physical volume created"
sudo vgcreate cinder-volumes /dev/sdb && echo "[OK] Volume group cinder-volumes created"

# --------------------------
confirm "Step 9: Prepare Kolla-OpenStack?"
kolla-ansible install-deps && echo "[OK] Dependencies installed"
kolla-genpwd && echo "[OK] Passwords generated"
kolla-ansible bootstrap-servers -i ./all-in-one && echo "[OK] Servers bootstrapped"
cat /etc/hosts
kolla-ansible prechecks -i ./all-in-one && echo "[OK] Prechecks done"

# --------------------------
confirm "Step 10: Deploy OpenStack with Kolla?"
kolla-ansible deploy -i ./all-in-one && echo "[OK] OpenStack deployed"

# --------------------------
confirm "Step 11: Post-deployment steps?"
sudo usermod -aG docker $USER && echo "[OK] User added to docker group"
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2024.1 && echo "[OK] python-openstackclient installed"
pip install python-neutronclient -c https://releases.openstack.org/constraints/upper/2024.1 && echo "[OK] python-neutronclient installed"
pip install python-glanceclient -c https://releases.openstack.org/constraints/upper/2024.1 && echo "[OK] python-glanceclient installed"
pip install python-heatclient -c https://releases.openstack.org/constraints/upper/2024.1 && echo "[OK] python-heatclient installed"

kolla-ansible post-deploy && echo "[OK] Post-deploy done"
source /etc/kolla/admin-openrc.sh
openstack service list && echo "[OK] OpenStack services listed"

echo "===== Kolla-OpenStack setup complete! ====="

