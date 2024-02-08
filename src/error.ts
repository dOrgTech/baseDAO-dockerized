class ResponseError extends Error {
    constructor(message) {
        super(message); 
        this.name = 'ResponseError'; 

        if (Error.captureStackTrace) {
            Error.captureStackTrace(this, ResponseError);
        }
    }
}

export {
    ResponseError
}