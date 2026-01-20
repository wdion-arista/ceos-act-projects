# syntax=docker/dockerfile:1.4

FROM ghcr.io/srl-labs/containerlab/devcontainer-dood:latest

ARG AVD_VERSION="5.6.0"
ENV AVD_VERSION=${AVD_VERSION}

ARG DOCKER_GID=2020
ENV DOCKER_GID=$DOCKER_GID

ARG GH_USERNAME
ENV GH_USERNAME=$GH_USERNAME
SHELL ["/bin/bash", "-c"]

USER root

RUN \
    # 1. Check if GID 1001 is already taken by another group
    existing_group=$(getent group 1001 | cut -d: -f1); \
    if [ -n "$existing_group" ]; then \
        echo "⚠️  GID 1001 is occupied by group '$existing_group'. Moving it to 9999..."; \
        groupmod -g 9999 $existing_group; \
    fi && \
    # 2. Now that 1001 is free, assign it to vscode
    usermod -u 1001 vscode && \
    groupmod -g 1001 vscode && \
    # 3. Fix ownership
    chown -R 1001:1001 /home/vscode

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

# Install gh and clean up
RUN apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Note: You were creating an 'avd' user (UID 2000) here, but never using it 
# for the final runtime (you switched back to vscode). I have left it in case 
# you need it, but 'vscode' is the user running your pipeline.
RUN useradd -m -u 2000 avd
RUN echo -e "\nexport PATH=\$PATH:/home/avd/.local/bin" >> /home/avd/.bashrc

# Configure ZSH/Bash for vscode
RUN echo -e "\nexport PATH=\$PATH:/home/vscode/.local/bin" >> /home/vscode/.zshrc
RUN echo -e "\nexport PATH=\$PATH:/home/vscode/.local/bin" >> /home/vscode/.bashrc

# Add helper functions to .zshrc
RUN echo -e "\n\
ceoscli() {\n\
  local name=\$1\n\
  local cid=\$(docker ps --filter \"name=\$name\" --format \"{{.ID}}\")\n\
  if [ -z \"\$cid\" ]; then\n\
    echo \"❌ Container with name containing '\$name' not found.\"\n\
    return 1\n\
  fi\n\
  docker exec -it \"\$cid\" /bin/bash -c \"Cli\"\n\
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

# Switch to the now-fixed vscode user (UID 1001)
USER vscode

# All pip installs will now belong to UID 1001
RUN pip install --upgrade pip 
ENV PATH="/home/vscode/.local/bin:${PATH}"
RUN curl https://pyenv.run | bash

# Install AVD
RUN pip install "pyavd[ansible]==${AVD_VERSION}" \
    && ansible-galaxy collection install arista.avd:==${AVD_VERSION}

# Install project requirements
RUN --mount=type=bind,source=/,target=/app/ pip install -r /app/requirements.txt
RUN --mount=type=bind,source=/,target=/app/ pip install --no-index --find-links=/app/wheelhouse actrac
RUN --mount=type=bind,source=/,target=/app/ ansible-galaxy install -g -f -r /app/requirements.yml

RUN pip install git+https://github.com/wdion-arista/ce_act_cli.git@wdion_clean_text_names

RUN activate-global-python-argcomplete