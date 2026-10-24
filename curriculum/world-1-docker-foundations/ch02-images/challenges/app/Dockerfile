FROM ubuntu:22.04 AS base

RUN apt-get update \
&& apt-get install -y curl wget git build-essential

ARG TARGETARCH
RUN wget https://go.dev/dl/go1.21.0.linux-${TARGETARCH}.tar.gz
RUN tar -C /usr/local -xzf go1.21.0.linux-${TARGETARCH}.tar.gz
RUN rm go1.21.0.linux-${TARGETARCH}.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

WORKDIR /app
COPY ./go.mod /app
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 go build -o bean-tracker .

FROM alpine:latest

RUN apk add --no-cache curl ca-certificates

WORKDIR /app

COPY --from=base /app/bean-tracker .

EXPOSE 8080
CMD ["./bean-tracker"]
