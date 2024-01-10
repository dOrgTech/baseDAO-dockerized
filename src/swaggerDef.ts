// swaggerDef.ts
import swaggerJsdoc from 'swagger-jsdoc';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'baseDAO API',
      version: '1.0.0',
      description: 'This is a simple API for baseDAO',
    },
  },
  apis: ['./src/controllers/*.ts'], // Path to the API docs
};

const swaggerSpec = swaggerJsdoc(options);

export default swaggerSpec;
