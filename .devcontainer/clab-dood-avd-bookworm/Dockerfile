# syntax=docker/dockerfile:1.4
#FROM ghcr.io/aristanetworks/avd/universal:python3.11-avd-v5.4.0



# Desired Docker GID

# FROM ghcr.io/srl-labs/containerlab/devcontainer-dood:latest
# FROM ghcr.io/aristanetworks/avd/universal:${AVD_VERSION}
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm


ARG AVD_VERSION="5.6.0"
ENV AVD_VERSION=${AVD_VERSION}

ARG DOCKER_GID=2020
ENV DOCKER_GID=$DOCKER_GID

ARG GH_USERNAME
ENV GH_USERNAME=$GH_USERNAME
SHELL ["/bin/bash", "-c"]

ARG CLAB_VERSION

USER root

### Base Installs

# Add the netdevops repository
RUN echo "deb [trusted=yes] https://netdevops.fury.site/apt/ /" | \
    tee -a /etc/apt/sources.list.d/netdevops.list

# Install necessary packages, including curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    direnv \
    btop \
    iputils-ping \
    tcpdump \
    iproute2 \
    qemu-kvm \
    dnsutils \
    telnet \
    curl

    # Install Containerlab
RUN bash -c "$(curl -sL https://get.containerlab.dev)" -- -v ${CLAB_VERSION}

# # Install GitHub CLI directly from the latest release
# RUN bash -c 'ARCH=$(uname -m | sed "s/x86_64/amd64/" | sed "s/aarch64/arm64/") && \
#     VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | \
#     grep -oP "\"tag_name\": \"\K[^\"]+") && \
#     CLEAN_VERSION=${VERSION#v} && \
#     DOWNLOAD_URL="https://github.com/cli/cli/releases/download/${VERSION}/gh_${CLEAN_VERSION}_linux_${ARCH}.tar.gz" && \
#     curl -L "$DOWNLOAD_URL" | tar xz -C /tmp && \
#     mv /tmp/gh_${CLEAN_VERSION}_linux_${ARCH}/bin/gh /usr/local/bin/ && \
#     chmod +x /usr/local/bin/gh && \
#     rm -rf /tmp/gh_${CLEAN_VERSION}_linux_${ARCH}'

# Add empty docker config files to avoid clab warnings for root user
RUN mkdir -p /root/.docker && echo "{}" > /root/.docker/config.json

# Maintain SSH_AUTH_SOCK env var when using sudo
RUN mkdir -p /etc/sudoers.d && echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/ssh_auth_sock

# Add vscode user to clab_admins group so that it can run sudo-less clab commands
# the group is created when clab is installed via the installation script
RUN groupadd clab_admins
RUN usermod -aG clab_admins vscode


### Base Installs END

USER root

RUN apt update \
    && apt autoremove -y \
    && wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64 -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

RUN apt install sshpass iputils-ping -y 
# Install dependencies
RUN apt-get update && \
    apt-get install -y curl ca-certificates gnupg && \
    mkdir -p -m 755 /etc/apt/keyrings

# Add the GitHub CLI GPG key
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

# Add the GitHub CLI repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# #RUN sudo apt-get purge -y moby-engine moby-cli moby-buildx moby-compose \
# #    && sudo apt-get autoremove -y \
# #    && sudo groupdel docker
# # RUN echo "Using DOCKER_GID=${DOCKER_GID}"
# # RUN sudo groupadd -g ${DOCKER_GID} docker


# Install gh and clean up
RUN apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create AVD user
RUN useradd -m -u 2000 avd

RUN echo -e "\nexport PATH=\$PATH:/home/avd/.local/bin" >> /home/avd/.bashrc
RUN echo -e "\nexport PATH=\$PATH:/home/vscode/.local/bin" >> /home/vscode/.zshrc
RUN echo -e "\nexport PATH=\$PATH:/home/vscode/.local/bin" >> /home/vscode/.bashrc
RUN echo -e "\n\
ceoscli() {\n\
  local name=$1\n\
  local cid=$(docker ps --filter "name=$name" --format "{{.ID}}")\n\
  if [ -z "$cid" ]; then\n\
    echo "❌ Container with name containing '$name' not found."\n\
    return 1\n\
  fi\n\
  docker exec -it "$cid" /bin/bash -c "Cli"\n\
}" >> /home/vscode/.zshrc

RUN echo -e "\n\
remove_non_vsc_containers() {\n\
  ids=\$(docker ps -a --format \"{{.ID}} {{.Image}}\" | awk '!/vsc-/{print \$1}' | grep -v '^\\s*\$')\n\
  if [ -z \"\$ids\" ]; then\n\
    echo \"✅ No containers to remove.\"\n\
  else\n\
    echo \"🗑 Removing containers:\"\n\
    echo \"\$ids\"\n\
    echo \"\$ids\" | xargs docker rm -f\n\
  fi\n\
}\n" >> /home/vscode/.zshrc

RUN echo -e "\n\
remove_dangling_images() {\n\
  ids=\$(docker images -f \"dangling=true\" -q | grep -v '^\\s*\$')\n\
  if [ -n \"\$ids\" ]; then\n\
    echo \"🗑 Removing dangling <none> images...\"\n\
    echo \"\$ids\" | xargs docker rmi\n\
  else\n\
    echo \"✅ No <none> images to remove.\"\n\
  fi\n\
}\n" >> /home/vscode/.zshrc

# Switch to avd user
# Switch to the vscode user provided by the base image
USER vscode

# Copy dclab script used to run the local containerlab build after `make build`
COPY ./dclab /usr/local/bin/dclab

# Create SSH key for vscode user to enable passwordless SSH to devices
RUN ssh-keygen -t ecdsa -b 256 -N "" -f ~/.ssh/id_ecdsa

# Add empty docker config files to avoid clab warnings for vscode user
RUN mkdir -p /home/vscode/.docker && echo "{}" > /home/vscode/.docker/config.json

# Setup Zsh and plugins
COPY ./zsh/.zshrc-slim /home/vscode/.zshrc
COPY ./zsh/.p10k.zsh /home/vscode/.p10k.zsh
COPY ./zsh/install-zsh-plugins.sh /tmp/install-zsh-plugins.sh
RUN bash -c "/tmp/install-zsh-plugins.sh"


RUN pip install --upgrade pip 
ENV PATH="/home/vscode/.local/bin:${PATH}"
RUN curl https://pyenv.run | bash

# install AVD
RUN pip install "pyavd[ansible]==${AVD_VERSION}" \
    && ansible-galaxy collection install arista.avd:==${AVD_VERSION}

# #RUN git config --global credential.helper store 

RUN --mount=type=bind,source=/,target=/app/ pip install -r /app/requirements.txt
RUN --mount=type=bind,source=/,target=/app/ pip install --no-index --find-links=/app/wheelhouse actrac
RUN --mount=type=bind,source=/,target=/app/ ansible-galaxy install -g -f -r /app/requirements.yml

RUN pip install  git+https://github.com/wdion-arista/ce_act_cli.git@wdion_clean_text_names

RUN  activate-global-python-argcomplete
#    && echo 'source /workspace/.env' >> ~/.bashrc
# # RUN --mount=type=secret,id=GH_TOKEN \
# #         pip install  git+https://${GH_USERNAME}:$(sudo cat /run/secrets/GH_TOKEN)@github.com/wdion-arista/ce_act_cli.git




