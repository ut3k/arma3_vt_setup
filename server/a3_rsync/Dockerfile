FROM alpine:latest

# Instalacja niezbędnych pakietów
RUN apk update && apk add --no-cache \
    openssh-server \
    rsync \
    bash \
    sudo

# Tworzenie użytkownika rsync
RUN adduser -D -s /bin/bash rsyncuser && \
    echo "rsyncuser:rsyncpass" | chpasswd && \
    echo "root:ppp" | chpasswd

# Konfiguracja SSH
RUN ssh-keygen -A

# Tworzenie katalogu dla danych
RUN mkdir -p /data

# Konfiguracja SSH - pozwolenie na logowanie root i użytkownika
RUN echo "Port 8873" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# Tworzenie katalogu .ssh dla root
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Skrypt startowy
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Eksponowanie portu
EXPOSE 8873



# Uruchomienie SSH daemon
CMD ["/start.sh"]
