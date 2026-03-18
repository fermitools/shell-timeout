FROM fedora:latest

RUN yum -y install csh zsh && yum clean all

RUN groupadd -g 2000 testgroup1 && \
    groupadd -g 2001 testgroup2 && \
    groupadd -g 3000 testgroup3 && \
    useradd -u 1000 -g testgroup1 -M -N testuser1 && \
    useradd -u 1001 -g testgroup2 -M -N testuser2 && \
    useradd -u 5555 -M testuser3
