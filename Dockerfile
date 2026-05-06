# syntax=docker/dockerfile:1

FROM ubuntu:22.04

WORKDIR /app

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    gcc curl git build-essential libglfw3-dev libglm-dev ripgrep fd-find wget xz-utils unzip libsfml-dev x11-apps xauth cmake

COPY . .

# # Gets overwritten by docker-compose anyways, so they'll have to build it manually.
# RUN cmake -B build/Release -DCMAKE_BUILD_TYPE=Release -S /app && \
#     cmake --build build/Release && \
#     cmake -B build/Debug -DCMAKE_BUILD_TYPE=Debug -S /app && \
#     cmake --build build/Debug
    