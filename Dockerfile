FROM alpine:latest as tailscale
WORKDIR /app
COPY . ./
ENV TSFILE=tailscale_1.24.2_amd64.tgz
RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && tar xzf ${TSFILE} --strip-components=1
COPY . ./

# set up tailscale
FROM golang:1.17.7-bullseye as litestream-builder

# set gopath for easy reference later
ENV GOPATH=/go

# install wget and unzip to download and extract litestream source
RUN apt-get update && apt-get install -y wget unzip

# download and extract litestream source
RUN wget https://github.com/benbjohnson/litestream/archive/refs/heads/main.zip
RUN unzip ./main.zip -d /src

# set working dir to litestream source
WORKDIR /src/litestream-main

# build and install litestream binary
RUN go install ./cmd/litestream

FROM node:16

# Installing libvips-dev for sharp Compatability
RUN apt-get update && apt-get install libvips-dev ca-certificates -y

# Set environment to production
ENV NODE_ENV=development

# Copy the configuration files
WORKDIR /opt/
COPY ./package.json ./package-lock.json ./
ENV PATH /opt/node_modules/.bin:$PATH

# Install dependencies
RUN npm install

# Copy the application files
WORKDIR /opt/app
COPY ./ .

# Build the Strapi application
RUN npm run build

# Expose the Strapi port
EXPOSE 1337

# copy litestream binary to /usr/local/bin
COPY --from=litestream-builder /go/bin/litestream /usr/bin/litestream
# copy litestream configs
ADD etc/litestream.primary.yml /etc/litestream.primary.yml
ADD etc/litestream.replica.yml /etc/litestream.replica.yml

ENV DATABASE_URL=file:/var/lib/ghost/content/db

ADD start.sh .

CMD [ "sh", "start.sh" ]
