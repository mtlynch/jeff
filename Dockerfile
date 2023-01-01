FROM golang:1.10
ENV SRC github.com/mtlynch/jeff
RUN curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
WORKDIR /go/src/${SRC}
