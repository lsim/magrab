const fs = require('fs');
const request = require('request');

const cameraUrl = 'http://camera/image/jpeg.cgi';
const cameraUser = 'admin';
const cameraPass = 'HDer1337';
const imageFolder = 'images';

function grabImage() {
  return new Promise((resolve, reject) => {
    const requestOptions = {
      uri: cameraUrl,
      auth: {
        user: cameraUser,
        pass: cameraPass,
        sendImmediately: false, // Support digest auth scheme
      },
    };
    const wstream = fs.createWriteStream(`${imageFolder}/image.jpg`);
    request
      .get(requestOptions)
      .on('error', e => reject(e))
      .on('response', (res) => {
        if (res.statusCode !== 200) reject(res.statusCode);
      })
      .on('end', () => resolve('image.jpg'))
      .pipe(wstream);
  });
}

module.exports = {
  grabImage,
};
