FROM alpine:3.20

RUN apk add --no-cache \
    openssh-server \
    rsync \
    bash \
    sudo

RUN adduser -D -s /bin/bash rsyncuser && \
    mkdir -p /data /run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    ssh-keygen -A

RUN { \
      echo "Port 8873"; \
      echo "PermitRootLogin prohibit-password"; \
      echo "PasswordAuthentication no"; \
      echo "PubkeyAuthentication yes"; \
      echo "AuthorizedKeysFile .ssh/authorized_keys"; \
    } >> /etc/ssh/sshd_config

COPY --chmod=755 start.sh /start.sh

EXPOSE 8873/tcp

CMD ["/start.sh"]
