import express, { Application as ExpressApp } from "express";
import cors from "cors";
import "dotenv/config";
import { controllers } from "./controllers";

const app: ExpressApp = express();
app.use(cors());
app.options('*', cors());
app.use("/", controllers);

export { app };
