FROM --platform=linux/amd64 ubuntu:latest

ARG VERSION

LABEL name="DBmarlin Agent" \
      vendor="DBmarlin" \
      version="${VERSION}" \
      release="1" \
      url="https://www.dbmarlin.com" \
      summary="DBmarlin agent" \
      description="DBmarlin agent running inside a container"

ENV LANG en_US.utf8

WORKDIR /opt/

RUN useradd dbmarlin 
RUN apt update -y
RUN apt-get install curl inetutils-tools locales -y 
RUN apt-get install iputils-ping -y

RUN curl https://download.dbmarlin.com/dbmarlin-agent-Linux-x64-$VERSION.tar.gz --output dbmarlin-agent-Linux-x64-$VERSION.tar.gz
RUN tar -xzvf dbmarlin-agent-Linux-x64-$VERSION.tar.gz

RUN chown dbmarlin:dbmarlin /opt/dbmarlin

RUN chmod 777 -R /opt/dbmarlin

RUN rm dbmarlin-agent-Linux-x64-$VERSION.tar.gz

RUN ls /usr/share/i18n/locales

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

USER dbmarlin 
WORKDIR /opt/dbmarlin

EXPOSE 9080

# Execute the agent-start.sh script in the agent
ENTRYPOINT [ "/bin/bash", "-l", "-c" ]
CMD [ "pwd && ls -l && whoami && /opt/dbmarlin/agent-start.sh && sleep 5 && tail -F /opt/dbmarlin/tomcat/logs/localhost*" ]
