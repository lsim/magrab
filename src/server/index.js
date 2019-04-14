#!/usr/bin/env node

const express = require('express');
const expressWS = require('express-ws');
const karhu = require('karhu');
const styles = require('ansi-styles');
const logConf = require('karhu/config/default');
const Datastore = require('nedb');
// Set up logging
logConf.colors.DEBUG = styles.blue;
logConf.colors.INFO = styles.yellowBright;
logConf.colors.WARN = styles.orange;
logConf.colors.ERROR = styles.red;
logConf.defaultLogLevel = 'DEBUG';
karhu.configure(logConf);
const log = karhu.context('index');
// Load internal dependencies
const images = require('./images');
const config = require('./config');

const { port, projectsDbFile, imagePath } = config;

// Set up persistence

const projectsDb = new Datastore({ filename: projectsDbFile, autoload: true });

// Set up express

const app = express();
expressWS(app);

app.use(express.static('./src/client'));
app.use(express.static(`./${imagePath}`)); // TODO: Hm .. that path has to be relative then

// Prune image files only at startup (when no undo buffer would be likely to cause trouble)
projectsDb.find({}, (err, projects) => {
  if (err) log.warn(`Error getting data for image prune ${err}`);
  else images.pruneOrphanImages(projects);
});

function sendState(ws) {
  log.debug('Sending state to browser');
  projectsDb.find({}, (err, projects) => {
    if (err) log.warn(`Error getting data for sendState ${err}`);
    else ws.send(`state:${JSON.stringify(projects).replace(/:/g, '<colon>')}`);
  });
}

function newProject(name, cb) {
  const p = {
    name,
    scenes: [
      {
        images: [],
      },
    ],
  };
  projectsDb.insert(p, cb);
  log.debug(`Project created: ${name}`);
}

app.ws('/connect', (websocket /* , request */) => {
  log.debug('A client connected!');
  sendState(websocket);
  websocket.on('message', (message) => {
    const [messageType, ...escapedArgs] = message.split(':');
    log.debug(`A client sent a ${messageType} message with ${escapedArgs.length} args`);
    const args = escapedArgs.map(s => s.replace(/<colon>/g, ':'));
    if (messageType === 'new-project' && args.length > 0) {
      newProject(args[0], (err) => {
        if (err) log.warn(`Error inserting new project ${err}`);
        else sendState(websocket);
      });
    } else if (messageType === 'save' && args.length > 0) {
      const [jsonString] = args;
      const projects = JSON.parse(jsonString);
      const promises = projects.map(p => new Promise((resolve, reject) => {
        log.debug(`Attempting to upsert with _id ${p.id}`);
        const { _id } = p;
        projectsDb.update({ _id }, p, { upsert: true },
          (err) => {
            log.debug(`Upsert finished for project ${p.name} - ${err}`);
            if (err) reject(err); else resolve(p);
          });
      }));
      Promise.all(promises).then(
        () => log.debug('Save successful'),
        err => log.warn(`Save failed ${err}`),
      );
    } else if (messageType === 'grab-image') {
      const [projectId, sceneIndex, cameraUrl, cameraUser, cameraPass] = args;
      images.grabImage(cameraUrl, cameraUser, cameraPass).then((fileName) => {
        websocket.send(`image-grabbed:${fileName}:${projectId}:${sceneIndex}`);
      }, err => log.warn(`Grab failed: ${err}`));
    }
  });
});

app.listen(port, () => log.info(`Magrab server listening on port ${port}!`));
