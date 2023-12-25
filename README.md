# baseDAO-dockerized

## Introduction
`baseDAO-dockerized` is a TypeScript server application tailored for Tezos decentralized autonomous organizations (DAOs). It specializes in converting input parameters into byte code for deploying DAOs on the Tezos blockchain. The application executes shell commands in a child process to generate byte code, which is then sent back to the front end for on-chain deployment. Integrated with a Heroku pipeline, this project supports both v2 and v3 versions of baseDAO, accommodating DAOs that have not transitioned to v3.

## Features
- **Byte Code Generation**: Converts parameters into byte code for DAO deployment on the Tezos blockchain.
- **Child Process Execution**: Runs necessary commands in a child process to facilitate byte code generation.
- **Front-End Integration**: Returns the byte code file to the front end for deploying the DAO on-chain.
- **Heroku Deployment**: Seamlessly deployed on Heroku with pipelines for both v2 and v3 baseDAO.

## Prerequisites
- [Node.js](https://nodejs.org/)
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Setup
Clone the repository and navigate to the directory:
```bash
git clone git@github.com:dOrgTech/baseDAO-dockerized.git
cd baseDAO-dockerized
```

## Using Docker Compose
Start the application in a local development environment:
```bash
docker-compose up
```

## API Documentation with Swagger
Access Swagger UI for API documentation and testing at:
```
http://localhost:3500/
```

## Deployment
The application is deployed on Heroku with separate remotes for different versions:
- v2 baseDAO: [https://git.heroku.com/v2-basedao-dockerized.git](https://git.heroku.com/v2-basedao-dockerized.git)
- v3 baseDAO: [https://git.heroku.com/v3-basedao-dockerised.git](https://git.heroku.com/v3-basedao-dockerised.git)

## Local Development Workflow
1. Make and test changes locally.
2. Use Docker Compose for building and testing in a containerized environment.

## Contribution Guidelines
We encourage contributions. If you'd like to contribute, please:
1. Fork the repository.
2. Create a new branch for your feature.
3. Commit your changes.
4. Push to the branch.
5. Open a pull request.

## License
`baseDAO-dockerized` is licensed under the [MIT License](LICENSE.md).