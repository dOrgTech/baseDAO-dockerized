FROM ubuntu:20.04
ENV NODE_VERSION=12.6.0
RUN apt update && apt install -y curl wget

#COPY SOURCES
COPY . ./app

#INSTALL NODE
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

#INSTALL STACK AND LIGO
RUN curl -sSL https://get.haskellstack.org/ | sh
RUN wget https://gitlab.com/ligolang/ligo/-/jobs/2702841321/artifacts/raw/ligo
RUN chmod +x ./ligo && cp ./ligo /usr/local/bin

#GENERATE CONTRACTS
RUN cd app/ligo && make all

#RUN NODE API
WORKDIR /app
RUN npm i
EXPOSE 3500

CMD [ "npm", "start" ]