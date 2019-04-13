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
karhu.configure(logConf);
const log = karhu.context('index');
// Load internal dependencies
const images = require('./images');
const config = require('./config');

const { port, projectsDbFile } = config;

// Set up persistence

const projectsDb = new Datastore({ filename: projectsDbFile, autoload: true });

// Set up express

const app = express();
expressWS(app);

app.use(express.static('./src/client'));
app.use(express.static('./images'));

function sendState(ws) {
  log.debug('Sending state to browser');
  projectsDb.find({}, (err, projects) => {
    ws.send(JSON.stringify(projects));
  });
}

function newProject(name, cb) {
  const p = {
    name,
    // id: uuid(),
    scenes: [
      {
        name: 'Scene 1',
        images: [],
      },
    ],
  };
  log.debug('Project created');
  projectsDb.insert(p, cb);
}

app.ws('/connect', (websocket /* , request */) => {
  log.debug('A client connected!');
  sendState(websocket);
  websocket.on('message', (message) => {
    log.debug(`A client sent a message: ${message}`);
    const [messageType, ...escapedArgs] = message.split(':');
    const args = escapedArgs.map(s => s.replace(/<colon>/g, ':'));
    if (messageType === 'new-project' && args.length > 0) {
      newProject(args[0], (err) => {
        if (err) log.warn(`Error inserting new project ${err}`);
        else sendState(websocket);
      });
    } else if (messageType === 'grab-image') {
      const [projectId, sceneIndex, cameraUrl, cameraUser, cameraPass] = args;
      images.grabImage(cameraUrl, cameraUser, cameraPass).then((fileName) => {
        const pushCommand = {};
        pushCommand[`scenes.${sceneIndex}.images`] = { path: fileName };
        projectsDb.update({ _id: projectId }, { $push: pushCommand }, {}, (err) => {
          if (err) log.warn(`Error adding image to project ${projectId}, scene index ${sceneIndex}: ${err}`);
          else sendState(websocket);
        });
      }, err => log.warn(`Grab failed: ${err}`));
    }
  });
});

app.listen(port, () => log.info(`Magrab server listening on port ${port}!`));
