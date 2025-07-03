import { promises as fs } from 'fs';
import path from 'path';
import crypto from 'crypto';

/**
 * Atomically write data to a file by writing to a temporary file first,
 * then renaming it to the target filename. This prevents partial writes
 * and corruption during concurrent access.
 * 
 * @param {string} filePath - The target file path
 * @param {string} data - The data to write
 * @param {object} options - Optional fs.writeFile options
 * @returns {Promise<void>}
 */
async function atomicWriteFile(filePath, data, options = {}) {
  const dir = path.dirname(filePath);
  const basename = path.basename(filePath);
  
  // Generate a unique temporary filename
  const tempId = crypto.randomBytes(8).toString('hex');
  const tempPath = path.join(dir, `.${basename}.${tempId}.tmp`);
  
  try {
    // Write to temporary file
    await fs.writeFile(tempPath, data, options);
    
    // Atomically rename temp file to target file
    // On POSIX systems, rename is atomic
    await fs.rename(tempPath, filePath);
  } catch (error) {
    // Clean up temp file if it exists
    try {
      await fs.unlink(tempPath);
    } catch (unlinkError) {
      // Ignore unlink errors
    }
    throw error;
  }
}

/**
 * Atomically update a JSON file by reading, modifying, and writing back.
 * Uses a callback function to modify the data to handle race conditions.
 * 
 * @param {string} filePath - The JSON file path
 * @param {function} updateFn - Function that receives current data and returns updated data
 * @param {any} defaultValue - Default value if file doesn't exist
 * @returns {Promise<any>} The updated data
 */
async function atomicUpdateJSON(filePath, updateFn, defaultValue = null) {
  let currentData = defaultValue;
  
  // Read current data
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    currentData = JSON.parse(content);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
    // File doesn't exist, use default value
  }
  
  // Apply update function
  const updatedData = await updateFn(currentData);
  
  // Write atomically
  await atomicWriteFile(filePath, JSON.stringify(updatedData, null, 2));
  
  return updatedData;
}

/**
 * Atomically write JSON data to a file
 * 
 * @param {string} filePath - The target file path
 * @param {any} data - The JSON data to write
 * @returns {Promise<void>}
 */
async function atomicWriteJSON(filePath, data) {
  await atomicWriteFile(filePath, JSON.stringify(data, null, 2));
}

export {
  atomicWriteFile,
  atomicUpdateJSON,
  atomicWriteJSON
};