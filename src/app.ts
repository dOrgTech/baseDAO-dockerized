import express, { Application as ExpressApp } from "express";
import "dotenv/config";
import { controllers } from "./controllers";

const app: ExpressApp = express();
app.use("/", controllers);

export { app };
