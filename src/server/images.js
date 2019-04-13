const fs = require('fs');
const request = require('request');
const log = require('karhu').context('images');
const uuid = require('uuid/v4');

const config = require('./config');

const { imagePath } = config;

function grabImage(cameraUrl, cameraUser, cameraPass) {
  return new Promise((resolve, reject) => {
    const requestOptions = {
      uri: cameraUrl,
      auth: {
        user: cameraUser,
        pass: cameraPass,
        sendImmediately: false, // Support digest auth scheme
      },
    };
    const fileName = `${uuid()}.jpg`;
    const wstream = fs.createWriteStream(`${imagePath}/${fileName}`);
    request
      .get(requestOptions)
      .on('error', e => reject(e))
      .on('response', (res) => {
        if (res.statusCode !== 200) reject(res.statusCode);
        else log.debug(`Camera gave 200 - image ${fileName}`);
      })
      .on('end', () => resolve(fileName))
      .pipe(wstream)
      .on('error', e => reject(e));
  });
}

module.exports = {
  grabImage,
};
