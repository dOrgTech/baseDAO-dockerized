import { join } from "path"
import { readFileSync } from "fs";
import { ulid } from 'ulid'
import { runCommand } from "../commands/command";
import { ResponseError } from "../error"
import { deleteDirectory, makeDirectoryIfNotExists, readFileContent } from "../utils/file.util";

export interface Storage {
  admin_address: string;
  token_address: string;
  frozen_scale_value: string;
  frozen_extra_value: string;
  max_proposal_size: string;
  slash_scale_value: string;
  slash_division_value: string;
  min_xtz_amount: string;
  max_xtz_amount: string;
}

export type Template = "registry" | "treasury" | "lambda"

/**
 * Generates steps based on the provided template and storage parameters.
 * @param {Template} template - The template type (registry, treasury, or lambda).
 * @param {Storage} storage - Storage parameters.
 * @param {string} originatorAddress - The address of the originator.
 * @returns An object containing the storage output.
 */
export const generateSteps = async (
  template: Template,
  storage: Storage,
  originatorAddress: string // TODO: Remove this safely
): Promise<{
  storage: string,
}> => {

  if (!storage['admin_address']) throw new ResponseError("admin_address is required");
  if (!storage['guardian_address']) throw new ResponseError("guardian_address is required");
  if (!storage['governance_token_id']) throw new ResponseError("governance_token_id is required");
  if (!storage['governance_token_address']) throw new ResponseError("governance_token_address is required");

  const ligoDirPath = join(process.cwd(), "ligo")

  // Create a unique execution ID for every request
  const executionId = ulid()
  const storageDir = join("out", executionId)
  makeDirectoryIfNotExists(storageDir)

  const storagePathArgument = join(storageDir, `${template === "lambda" ? "lambda" : template}DAO_storage.tz`)
  const storagePath = join(ligoDirPath, storagePathArgument)
  console.log("storagepath", storagePath)

  const command = `cd ${join(process.cwd(), "ligo")} && ls &&  make ${Object.keys(storage).map(
    (key) => `${key}=${storage[key]}`
  ).join(" ")} OUT=${storageDir} ${storagePathArgument}`

  await runCommand(command, false, executionId)

  // await runCommand(
  //   `cd ${join(process.cwd(), "ligo")} && make originate-steps storage=${storagePathArgument} \
  //   admin_address=${originatorAddress} destination=${stepsPathArgument}`
  // )

  // const stepsFiles = readdirSync(stepsPath)
  // stepsFiles.forEach(file => {
  //   steps[file] = readFileSync(join(stepsPath, file), "utf-8")
  // })

  const storageOutput = readFileContent(storagePath)

  deleteDirectory(join(process.cwd(), "ligo", storageDir)).catch(err => {
    console.warn("Error Deleting Directory", err)
  })

  return { storage: storageOutput }
};
