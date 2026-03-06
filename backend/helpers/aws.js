const AWS = require("aws-sdk");
const { v4: uuidv4 } = require("uuid");

AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});

const s3 = new AWS.S3();
const bucketName = process.env.AWS_S3_BUCKET_NAME;

/**
 * Upload file to S3
 * @param {Buffer} fileBuffer - The file buffer
 * @param {string} fileName - Original file name
 * @param {string} folderName - Folder name in S3 bucket
 * @param {string} mimeType - File mime type
 * @returns {Promise<string>} - Returns the file URL
 */
const uploadToS3 = async (fileBuffer, fileName, folderName, mimeType) => {
  const key = `${folderName}/${uuidv4()}-${fileName}`;

  const params = {
    Bucket: bucketName,
    Key: key,
    Body: fileBuffer,
    ContentType: mimeType,
    // ACL: "public-read",
  };

  try {
    const result = await s3.upload(params).promise();
    return result.Location;
  } catch (error) {
    console.error("Error uploading to S3:", error);
    throw new Error("Failed to upload file to S3");
  }
};

/**
 * Delete file from S3
 * @param {string} fileUrl - The complete file URL
 * @returns {Promise<void>}
 */
const deleteFromS3 = async (fileUrl) => {
  // Extract key from URL
  const urlParts = fileUrl.split("/");
  const key = urlParts.slice(3).join("/"); // Skip protocol and bucket name parts

  const params = {
    Bucket: bucketName,
    Key: key,
  };

  try {
    await s3.deleteObject(params).promise();
  } catch (error) {
    console.error("Error deleting from S3:", error);
    throw new Error("Failed to delete file from S3");
  }
};

module.exports = {
  s3,
  uploadToS3,
  deleteFromS3,
};
