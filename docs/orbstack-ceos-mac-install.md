# OrbStack cEOS Mac Install

References:
- [Getting Started with cEOS-lab in Containerlab](https://arista.my.site.com/AristaCommunity/s/article/Getting-Started-with-cEOS-lab-in-Containerlab)
- [cEOS-lab in Github Codespaces](https://arista.my.site.com/AristaCommunity/s/article/cEOS-lab-in-Github-Codespaces)
- [cEOS-lab on Orbstack](https://arista.my.site.com/AristaCommunity/s/article/cEOS-lab-on-Orbstack)
- [cEOS and Containerlab on Windows WSL](https://arista.my.site.com/AristaCommunity/s/article/cEOS-and-Containerlab-on-Windows-WSL)

## Arista cEOSarm Setup

1. Install OrbStack for Mac

   ```
   brew install orbstack
   ```

2. Run OrbStack config script. This will setup Docker (Moby) and a few tools using cloud-init. It will set the CPU to 8 and Memory to 24 by default. OrbStack uses max CPU and 16 GB of RAM.

   ```
   cd scripts/debian
   ./shell-init.sh
   ```
   ```
   # Optionally set CPU and Memory (example: 8 CPU and 28 GB RAM):
   ./shell-init.sh 8 28
   orb stop
   orb start
   ```
   ![orbstack install script](../scripts/debian/images/macos_orbstack_init.gif)

3. Create ARM VM

   ![create vm](../scripts/debian/images/orbstack_vm_create.png)
   ```
   orb create -a arm64 debian debian --user-data cloud-config.yml
   ssh orb
   sudo usermod -aG docker $USER
   ```
   ![orbstack create vm with docker](../scripts/debian/images/macos_orbstack_create_vm.gif)

4. Login to VM and assign your user

   ```
   ssh orb
   sudo usermod -aG docker $USER
   ```
   ![orbstack login and assign group](../scripts/debian/images/macos_orbstack_login.gif)

## Connecting with VSCode

- Plugin dependency: Remote SSH extension

  ![vscode remote extension](../scripts/debian/images/vscode_remote-ssh.png)

1. VSCode -> Remotes (Tunnels/SSH) -> orb -> Connect in new window

   ![vscode remote connect](../scripts/debian/images/vscode_remote_connect.png)

2. Open the containerlab repo folder from your host-mounted folder, e.g. `/Users/%username%/Projects/repos/ceos-act-projects`

3. Choose Reopen in Container, then select the AVD Containerlab devcontainer

   ![vscode open container](../scripts/debian/images/vscode_reopen_container.png)

4. Select the `.devcontainer` file for AVD

   ![vscode select container](../scripts/debian/images/vscode_container_select.png)
