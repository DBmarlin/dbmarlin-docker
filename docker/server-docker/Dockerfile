FROM --platform=linux/amd64 ubuntu:latest

ARG VERSION

LABEL name="DBmarlin Server" \
      vendor="DBmarlin" \
      version="${VERSION}" \
      release="1" \
      url="https://www.dbmarlin.com" \
      summary="DBmarlin server" \
      description="DBmarlin server running inside a container"

ENV LANG en_US.utf8

WORKDIR /opt/

RUN useradd dbmarlin 
RUN apt update -y
RUN apt-get install curl inetutils-tools locales -y 
RUN apt-get install iputils-ping -y

RUN curl https://download.dbmarlin.com/dbmarlin-Linux-x64-$VERSION.tar.gz --output dbmarlin-Linux-x64-$VERSION.tar.gz
RUN tar -xzvf dbmarlin-Linux-x64-$VERSION.tar.gz

RUN chown dbmarlin:dbmarlin /opt/dbmarlin

RUN chmod 777 -R /opt/dbmarlin

RUN rm dbmarlin-Linux-x64-$VERSION.tar.gz

RUN ls /usr/share/i18n/locales

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

USER dbmarlin 
WORKDIR /opt/dbmarlin
RUN ./configure.sh -a -n9090 -t9080 -p9070 -sSmall -u

EXPOSE 9090

# Execute the agent-start.sh script in the agent
ENTRYPOINT [ "/bin/bash", "-l", "-c" ]
CMD [ "pwd && ls -l && whoami && /opt/dbmarlin/start.sh && sleep 5 && tail -F /opt/dbmarlin/tomcat/logs/localhost*.log" ]
