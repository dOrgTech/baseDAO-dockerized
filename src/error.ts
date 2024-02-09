import { exec, ExecException } from "child_process";

class ResponseError extends Error {
    constructor(message) {
        super(message); 
        this.name = 'ResponseError'; 

        if (Error.captureStackTrace) {
            Error.captureStackTrace(this, ResponseError);
        }
    }
}

class CliError extends Error {
    executionId: string;
    constructor(message, executionId?:string) {
        super(message); 
        this.name = 'CliError'; 
        this.executionId = executionId

        if (Error.captureStackTrace) {
            Error.captureStackTrace(this, CliError);
        }
    }
}

export {
    CliError,
    ResponseError
}