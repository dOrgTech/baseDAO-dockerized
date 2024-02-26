import fs from 'fs';
import { existsSync, mkdirSync, readFileSync} from "fs";

/**
 * Create a directory if it does not exist
 * @param {string} dirPath - Path to the directory
 */
function makeDirectoryIfNotExists(dirPath) {
    if (!existsSync(dirPath)) {
        mkdirSync(dirPath, { recursive: true });
    }
};


/**
 * Read the content of a file
 * @param {string} filePath - Path to the file
 */
function readFileContent(filePath) {
    return readFileSync(filePath, "utf-8")
}

/**
 * Delete a directory recursively
 * @param {string} dirPath - Path to the directory
 */
async function deleteDirectory(dirPath) {
    fs.rmdir(dirPath, { recursive: true }, (err) => {
        if (err) {
            throw err;
        }
        console.log(`${dirPath} is deleted!`);
    });
}


export {
    makeDirectoryIfNotExists,
    deleteDirectory,
    readFileContent,
}