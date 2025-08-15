FROM trailofbits/eth-security-toolbox

USER root

RUN apt-get update && \
    apt-get install -y just

WORKDIR /app

COPY . .

RUN forge install
RUN forge soldeer install

ENTRYPOINT ["just"]
