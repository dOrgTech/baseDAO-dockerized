import { join } from "path"
import { readdirSync, readFileSync } from "fs";
import { runCommand } from "../commands/command";
import rimraf from "rimraf"

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

export type Template = "registry" | "treasury"

export const generateSteps = async (template: Template, storage: Storage, originatorAddress: string) => {
  const ligoDirPath = join(process.cwd(), "ligo")
  const storagePathArgument = join("out", `${template}DAO_storage.tz`)
  const storagePath = join(ligoDirPath, storagePathArgument)
  const stepsPathArgument = join("out", "steps")
  const stepsPath = join(ligoDirPath, stepsPathArgument)
  const steps: Record<string, string> = {};

  await runCommand(
    `cd ${join(process.cwd(), "ligo")} && ls && make ${Object.keys(storage).map(
      (key) => `${key}=${storage[key]}`
    ).join(" ")} ${storagePathArgument}`
  );

  await runCommand(
    `cd ${join(process.cwd(), "ligo")} && make originate-steps storage=${storagePathArgument} \
    admin_address=${originatorAddress} destination=${stepsPathArgument}`
  )

  const stepsFiles = readdirSync(stepsPath)
  stepsFiles.forEach(file => {
    steps[file] = readFileSync(join(stepsPath, file), "utf-8")
  })

  const storageOutput = readFileSync(storagePath, "utf-8")

  rimraf.sync(storagePath)
  rimraf.sync(stepsPath)

  return { steps, storage: storageOutput }
};
