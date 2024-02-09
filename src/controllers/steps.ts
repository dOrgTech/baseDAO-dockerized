import { Request, Response, Router } from "express";
import { generateSteps, Template } from "../services/generateSteps";
import { CliError, ResponseError } from "../error";

const router = Router();

const getSteps = async (request: Request, response: Response) => {
  try {
    const storage = request.query as any;
    const { originator, template } = request.params
    console.log({
      "Template": template,
      "Orig": originator,
      "Stor": storage
    })

    const stepsAndStorage = await generateSteps(template as Template, storage, originator);
    response.status(200).json(stepsAndStorage);
  } catch (e) {

    if(e instanceof ResponseError){
      response.status(400).json({
        message: e?.message,
      });
    }
    else if(e.name === 'CliError'){
      response.status(500).json({
        message: 'Something Went Wrong',
        context: e?.executionId
      });
    }
    else{
      response.status(500).json({
        message: "An error has ocurred",
      });
    }
  }
  finally{
    response.end()
  }
};

/**
 * @swagger
 * /steps/{originator}/{template}:
 *   get:
 *     summary: Retrieve steps based on the template and originator
 *     description: Fetches steps according to the specified template and originator.
 *     parameters:
 *       - in: path
 *         name: originator
 *         required: true
 *         description: Unique identifier of the originator.
 *         schema:
 *           type: string
 *       - in: path
 *         name: template
 *         required: true
 *         description: Name of the template.
 *         schema:
 *           type: string
 *       - in: query
 *         name: storage
 *         description: Storage query parameters.
 *         schema:
 *           type: object
 *           properties:
 *             admin_address:
 *               type: string
 *             token_address:
 *               type: string
 *             frozen_scale_value:
 *               type: string
 *             frozen_extra_value:
 *               type: string
 *             max_proposal_size:
 *               type: string
 *             slash_scale_value:
 *               type: string
 *             slash_division_value:
 *               type: string
 *             min_xtz_amount:
 *               type: string
 *             max_xtz_amount:
 *               type: string
 *     responses:
 *       200:
 *         description: Successfully retrieved steps.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 storage:
 *                   type: string
 *       500:
 *         description: Internal server error.
 */
router.get("/steps/:originator/:template", getSteps);

export { router as StepsController };
