FROM node:18-alpine

RUN mkdir -p /src/app

COPY . /src/app

WORKDIR /src/app

EXPOSE 8888
ENTRYPOINT [ "tail", "-f" ]

# ENTRYPOINT [ "sh", "/src/app/scripts/init.sh" ]
