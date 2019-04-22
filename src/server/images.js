const fs = require('fs');
const request = require('request');
const log = require('karhu').context('images');
const uuid = require('uuid/v4');
const { exec } = require('child_process');
const rimraf = require('rimraf');


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
      const promises = orphans
        .filter(f => f.endsWith('.jpg'))
        .map(
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
      const promises = gifFiles
        .filter(f => f.endsWith('.gif'))
        .map(
          gf => new Promise((rmResolve, rmReject) => fs.unlink(`${gifPath}/${gf}`,
            rmErr => (rmErr ? rmReject(rmErr) : rmResolve()))),
        );
      return Promise.all(promises);
    });
  });
}

const padToFive = number => (number <= 99999 ? `0000${number}`.slice(-5) : number);

function prepareImagesForEncoding(tmpPath, fileNames) {
  // Create folder and create symlinks to the given file names
  // with numbers in them to indicate the sequence to ffmpeg
  rimraf.sync(tmpPath);
  fs.mkdirSync(tmpPath);
  fileNames.forEach((fileName, index) => {
    fs.symlinkSync(`${imagePath}/${fileName}`, `${tmpPath}/${padToFive(index)}.jpg`);
  });
}

function makeVideoFromImages(fileNames) {
  const tmpPath = `${imagePath}/tmp`;
  const outFileName = `${uuid()}.mkv`;
  const outputPath = `${tmpPath}/${outFileName}`;
  const imagesPerSecond = 10;
  return new Promise((resolve, reject) => {
    prepareImagesForEncoding(tmpPath, fileNames);
    // Call command line tool made available in docker image
    exec(`ffmpeg -r ${imagesPerSecond} -f image2 -vcodec mjpeg -pix_fmt rgb24 -i "${tmpPath}/%05d.jpg" ${outputPath}`, (err, stdout, stderr) => {
      if (err) return reject(err);
      log.debug(stderr);
      resolve(`tmp/${outFileName}`);
      return null;
    });
  });
}

module.exports = {
  grabImage,
  pruneOrphanImages,
  pruneGifs,
  makeVideoFromImages,
};
