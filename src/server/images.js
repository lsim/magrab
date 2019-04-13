const fs = require('fs');
const request = require('request');

// const cameraUrl = 'http://camera/image/jpeg.cgi';
// const cameraUser = 'admin';
// const cameraPass = 'HDer1337';
const imageFolder = 'images'; // TODO: get from configuration

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
    const fileName = `${Math.floor(Math.random() * 10000000)}.jpg`; // TODO: GUIDs?
    const wstream = fs.createWriteStream(`${imageFolder}/${fileName}`);
    request
      .get(requestOptions)
      .on('error', e => reject(e))
      .on('response', (res) => {
        if (res.statusCode !== 200) reject(res.statusCode);
        else console.log(`Camera gave 200 - image ${fileName}`);
      })
      .on('end', () => resolve(fileName))
      .pipe(wstream);
  });
}

module.exports = {
  grabImage,
};
