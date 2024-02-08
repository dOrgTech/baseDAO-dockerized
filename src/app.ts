import express, { Application } from 'express';
import cors from 'cors';
import swaggerUi from 'swagger-ui-express';
import swaggerSpec from './swaggerDef';
import { controllers } from './controllers';

const app: Application = express();

app.use(cors());
app.options('*', cors());

// Set up Swagger UI at the root path
// app.use('/', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Add other controllers
controllers.forEach((controller) => {
    app.use(controller);
});

export { app };
