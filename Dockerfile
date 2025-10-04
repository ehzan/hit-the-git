FROM ubuntu:24.04

ENV DIR="/hit-the-git"

WORKDIR $DIR

RUN apt update
RUN apt install -y git sudo curl faketime
# RUN rm -rf /var/lib/apt/lists/*
    	
RUN git config --global --add safe.directory $DIR
