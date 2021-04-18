ARG IMAGE=store/intersystems/iris-community:2020.1.0.204.0
ARG IMAGE=intersystemsdc/iris-community:2020.1.0.209.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.2.0.204.0-zpm
ARG IMAGE=intersystemsdc/irishealth-community:2020.3.0.200.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.3.0.200.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.3.0.221.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.4.0.524.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.4.0.547.0-zpm
FROM $IMAGE

USER root

RUN apt-get update && apt-get install -y git curl


RUN mkdir /opt/iriscode && chown ${ISC_PACKAGE_IRISUSER}:${ISC_PACKAGE_IRISGROUP} /opt/iriscode && chmod 775 /opt/iriscode

# Prepare a code directory and run git init
USER ${ISC_PACKAGE_IRISUSER}
WORKDIR /opt/iriscode
RUN git init && git config --global user.email "git@on.iris" && git config --global user.name "Git on IRIS"


USER root
WORKDIR /opt/irisbuild
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild

USER ${ISC_PACKAGE_MGRUSER}

#COPY  Installer.cls .
COPY src src
COPY module.xml module.xml
COPY iris.script iris.script

RUN iris start IRIS \
	&& iris session IRIS < iris.script \
    && iris stop IRIS quietly
