import { join } from "path"
import fs from 'fs';
import { readdirSync, readFileSync, existsSync, mkdirSync, rmdir } from "fs";
import { ulid } from 'ulid'
import { runCommand } from "../commands/command";
import rimraf from "rimraf"
import {ResponseError} from "../error"

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

const makeDirectoryIfNotExists = (dirPath) => {
  if (!existsSync(dirPath)) {
    mkdirSync(dirPath, { recursive: true });
  }
};

async function deleteDirectory(dirPath) {
  try {
    fs.rmdir(dirPath, { recursive: true }, (err) => {
      if (err) {
        throw err;
      }    
      console.log(`${dirPath} is deleted!`);
    });
  } catch (error) {
    console.error(`Error deleting directory ${dirPath}: ${error}`);
  }
}

/**
 * Generates steps based on the provided template and storage parameters.
 * @param {Template} template - The template type (registry, treasury, or lambda).
 * @param {Storage} storage - Storage parameters.
 * @param {string} originatorAddress - The address of the originator.
 * @returns An object containing the storage output.
 */
export const generateSteps = async (template: Template, storage: Storage, originatorAddress: string) => {

  if(!storage['admin_address']) throw new ResponseError("admin_address is required");
  if(!storage['guardian_address']) throw new ResponseError("guardian_address is required");
  if(!storage['governance_token_id']) throw new ResponseError("governance_token_id is required");
  if(!storage['governance_token_address']) throw new ResponseError("governance_token_address is required");
  

  const ligoDirPath = join(process.cwd(), "ligo")
  const executionId = ulid()
  const storageDir = join("out", executionId)
  makeDirectoryIfNotExists(storageDir)

  const storagePathArgument =  join(storageDir,`${template === "lambda" ? "lambda": template}DAO_storage.tz`)
  const storagePath = join(ligoDirPath, storagePathArgument)
  // const stepsPathArgument = join("out", "steps")
  // const stepsPath = join(ligoDirPath, stepsPathArgument)
  // const steps: Record<string, string> = {};
  console.log("storagepath", storagePath)

  try {
    await runCommand(
      `cd ${join(process.cwd(), "ligo")} && ls &&  make ${Object.keys(storage).map(
        (key) => `${key}=${storage[key]}`
      ).join(" ")} OUT=${storageDir} ${storagePathArgument}`
    );
  } catch(e) {
    console.log(e)
  }

  // await runCommand(
  //   `cd ${join(process.cwd(), "ligo")} && make originate-steps storage=${storagePathArgument} \
  //   admin_address=${originatorAddress} destination=${stepsPathArgument}`
  // )

  // const stepsFiles = readdirSync(stepsPath)
  // stepsFiles.forEach(file => {
  //   steps[file] = readFileSync(join(stepsPath, file), "utf-8")
  // })

  const storageOutput = readFileSync(storagePath, "utf-8")

  try {
    deleteDirectory(join(process.cwd(), "ligo", storageDir))
    // rimraf.sync(stepsPath)
  } catch(e) {
    console.log(e)
  }

  return { storage: storageOutput }
};
