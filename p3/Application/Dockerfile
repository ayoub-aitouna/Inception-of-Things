FROM node:18-alpine

RUN mkdir -p /src/app

COPY . /src/app

WORKDIR /src/app

EXPOSE 8888
    
ENTRYPOINT [ "sh", "/src/app/scripts/init.sh" ]
