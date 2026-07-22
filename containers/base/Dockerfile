# syntax=docker/dockerfile:1.4
# Local wdion repo
# ARG ACLABS_VERSION="python3.12-avd-v5.7.2-clab0.73.0-rev2.100.4"
# FROM ghcr.io/wdion-arista/aclabs/lab-base:${ACLABS_VERSION}


ARG ACLABS_VERSION="python3.12-avd-v5.7.3-clab0.77.0-rev2.6.8"
FROM ghcr.io/aristanetworks/aclabs/lab-base:${ACLABS_VERSION}
ENV ACLABS_VERSION=${ACLABS_VERSION}

ARG GH_USERNAME
ENV GH_USERNAME=$GH_USERNAME
SHELL ["/bin/bash", "-c"]

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

# Install gh and clean up
RUN apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Optional: Claude Code — pass --build-arg INSTALL_CLAUDE_CODE=true to enable
ARG INSTALL_CLAUDE_CODE=false
RUN if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    npm config set prefix '/home/avd/.npm-global' && \
    npm install -g @anthropic-ai/claude-code; \
    fi
ENV PATH="/home/avd/.npm-global/bin:${PATH}"

RUN echo -e "\nexport PATH=\$PATH:/home/avd/.local/bin" >> /home/avd/.bashrc
RUN echo -e "\n\
ceoscli() {\n\
  local name=\$1\n\
  local cid=\$(docker ps --filter \"name=\$name\" --format \"{{.ID}}\")\n\
  if [ -z \"\$cid\" ]; then\n\
    echo \"Container with name containing '\$name' not found.\"\n\
    return 1\n\
  fi\n\
  docker exec -it \"\$cid\" /bin/bash -c \"Cli\"\n\
}\n\
remove_non_vsc_containers() {\n\
  ids=\$(docker ps -a --format \"{{.ID}} {{.Image}}\" | awk '!/vsc-/{print \$1}' | grep -v '^\s*\$')\n\
  if [ -z \"\$ids\" ]; then\n\
    echo \"No containers to remove.\"\n\
  else\n\
    echo \"\$ids\" | xargs docker rm -f\n\
  fi\n\
}\n\
remove_dangling_images() {\n\
  ids=\$(docker images -f \"dangling=true\" -q | grep -v '^\s*\$')\n\
  if [ -n \"\$ids\" ]; then\n\
    echo \"\$ids\" | xargs docker rmi\n\
  fi\n\
}" >> /home/avd/.bashrc

USER avd
RUN pip install --upgrade pip
ENV PATH="/home/avd/.local/bin:${PATH}"

RUN --mount=type=bind,source=/,target=/app/ pip install -r /app/requirements.txt
RUN --mount=type=bind,source=/,target=/app/ pip install --no-index --find-links=/app/wheelhouse actrac
RUN --mount=type=bind,source=/,target=/app/ ansible-galaxy install -g -f -r /app/requirements.yml

RUN pip install git+https://github.com/wdion-arista/ce_act_cli.git@main

RUN activate-global-python-argcomplete
