import { exec, ExecException } from "child_process";
import { CliError } from "../error";

export async function runCommand(
  command: string,
  quiet = false,
  executionId = "",
): Promise<string> {
  console.log(`> ${command}`);
  if (!quiet) {
    console.log(`> ${command}`);
  }

  return new Promise<string>((resolve, reject) => {
    const callback = (
      err: ExecException | null,
      stdout: string,
      stderr: string
    ) => {
      if (err) {
        console.error(err);
        reject(new CliError(`[${executionId}] Error running command: ${command}`, executionId));
      } else {
        if (!quiet) {
          // the *entire* stdout and stderr (buffered)
          console.log(`stdout: ${stdout}`);
          console.log(`stderr: ${stderr}`);
        }

        resolve(stdout);
      }
    };

    exec(command, { cwd: __dirname }, callback);
  });
}
