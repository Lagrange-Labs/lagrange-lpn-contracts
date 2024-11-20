FROM trailofbits/eth-security-toolbox

USER root

RUN apt-get update && \
    apt-get install -y make

WORKDIR /app

COPY . .

# Make the script executable
RUN chmod +x /app/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
