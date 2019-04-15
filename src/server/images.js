const fs = require('fs');
const request = require('request');
const log = require('karhu').context('images');
const uuid = require('uuid/v4');
const GifEncoder = require('gif-encoder');
const getPixels = require('get-pixels');


const config = require('./config');

const { imagePath, gifPath } = config;

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

function pruneOrphanImages(projects) {
  const flatten = arrs => Array.prototype.concat.apply([], arrs);
  const referencedImageNames = flatten(
    projects.map(p => flatten(
      p.scenes.map(s => s.images.map(i => i.path)),
    )),
  );
  log.info(`Pruning images in ${imagePath}`);
  return new Promise((resolve, reject) => {
    fs.readdir(imagePath, (err, imageFiles) => {
      if (err) return reject(err);
      const orphans = imageFiles.filter(i => referencedImageNames.indexOf(i) === -1);
      if (!orphans || orphans.length === 0) return resolve();
      log.info(`Deleting ${orphans.length} files`);
      const promises = orphans.map(
        o => new Promise(
          (rmResolve, rmReject) => fs.unlink(`${imagePath}/${o}`,
            rmErr => (rmErr ? rmReject(rmErr) : rmResolve())),
        ),
      );
      return Promise.all(promises);
    });
  });
}

function pruneGifs() {
  return new Promise((resolve, reject) => {
    log.info(`Pruning gifs in ${gifPath}`);
    fs.readdir(gifPath, (err, gifFiles) => {
      if (err) return reject(err);
      if (!gifFiles || gifFiles.length === 0) return resolve();
      log.info(`Deleting ${gifFiles.length} gifs`);
      const promises = gifFiles.map(
        gf => new Promise((rmResolve, rmReject) => fs.unlink(`${gifPath}/${gf}`,
          rmErr => (rmErr ? rmReject(rmErr) : rmResolve()))),
      );
      return Promise.all(promises);
    });
  });
}

function buildGifForImages(fileNames) {
  if (!fileNames || fileNames.length === 0) {
    log.warn('buildGifForImages was given no images!');
    return Promise.reject();
  }
  const gifFileName = `${uuid()}.gif`;
  let gif = null;

  return new Promise((resolve, reject) => {
    const encodeFrame = (index = 0) => {
      getPixels(`${imagePath}/${fileNames[index]}`, (err, pixels) => {
        if (err) reject(Error(`Error encoding frame ${fileNames[index]} at index ${index}: ${err}`));
        else {
          if (index === 0) { // We can now detect the dimensions of the images
            const [width, height] = pixels.shape;
            gif = new GifEncoder(width, height);
            const file = fs.createWriteStream(`${gifPath}/${gifFileName}`);
            gif.pipe(file);
            gif.setQuality(5); // Higher is worse quality, higher speed?
            gif.setFrameRate(10);
            gif.setRepeat(0);
            gif.writeHeader();
          }
          gif.addFrame(pixels.data);
          gif.read();
          if (index + 1 < fileNames.length) encodeFrame(index + 1);
          else {
            gif.finish();
            resolve(gifFileName);
          }
        }
        return undefined;
      });
    };
    encodeFrame();
  });
}

module.exports = {
  grabImage,
  pruneOrphanImages,
  buildGifForImages,
  pruneGifs,
};
