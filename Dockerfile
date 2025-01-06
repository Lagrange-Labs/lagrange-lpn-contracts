FROM trailofbits/eth-security-toolbox

USER root

RUN apt-get update && \
    apt-get install -y make

WORKDIR /app

COPY . .

RUN forge install

ENTRYPOINT ["make"]
