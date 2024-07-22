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

RUN mkdir /dbmarlin-install
RUN mkdir /opt/dbmarlin
RUN useradd dbmarlin
RUN apt update -y
RUN apt-get install curl inetutils-tools locales -y 
RUN apt-get install iputils-ping -y
RUN apt-get install net-tools -y
RUN apt-get install apache2-utils -y
RUN apt-get install openssl -y
RUN apt-get install vim -y

RUN curl https://download.dbmarlin.com/dbmarlin-Linux-x64-$VERSION.tar.gz --output dbmarlin-Linux-x64-$VERSION.tar.gz
RUN tar -xzvf dbmarlin-Linux-x64-$VERSION.tar.gz -C /dbmarlin-install/

COPY start-and-tail.sh /opt/dbmarlin/start-and-tail.sh
COPY start-and-tail.sh /dbmarlin-install/dbmarlin/start-and-tail.sh

RUN chown -R dbmarlin:dbmarlin /dbmarlin-install
RUN chown -R dbmarlin:dbmarlin /opt/dbmarlin

RUN chmod 777 -R /dbmarlin-install
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

EXPOSE 9090

# Startup DBmarlin and tail logs
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/opt/dbmarlin/start-and-tail.sh"]
