import { Request, Response, Router } from "express";
import { generateSteps, Template } from "../services/generateSteps";

const router = Router();

const getSteps = async (request: Request, response: Response) => {
  try {
    const storage = request.query as any;
    const { originator, template } = request.params

    const stepsAndStorage = await generateSteps(template as Template, storage, originator);
    response.status(200).json(stepsAndStorage);
  } catch (e) {
    console.log(e);

    response.status(500).json({
      message: "An error has ocurred",
    });
  }
};

router.get("/steps/:originator/:template", getSteps);

export { router as StepsController };
