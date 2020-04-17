FROM nginx:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
	curl \
	wget \
	zip \
	unzip \
	ed

RUN apt-get autoremove -y