#!/usr/bin/env node

const express = require('express');
const expressWS = require('express-ws');
const karhu = require('karhu');
const styles = require('ansi-styles');
const logConf = require('karhu/config/default');

const log = karhu.context('index');

logConf.colors.DEBUG = styles.blue;
logConf.colors.INFO = styles.yellowBright;
logConf.colors.WARN = styles.orange;
logConf.colors.ERROR = styles.red;

karhu.configure(logConf);

const images = require('./images');
const config = require('./config');

const { port } = config;

const app = express();
expressWS(app);


app.use(express.static('./src/client'));
app.use(express.static('./images'));

const projects = [];

function sendState(ws) {
  log.debug('Sending state to browser');
  ws.send(JSON.stringify(projects));
}

function newProject(name) {
  const p = {
    name,
    id: projects.length.toString(), // TODO: could be GUID
    scenes: [
      {
        name: 'Scene 1',
        images: [],
      },
    ],
  };
  log.debug('Project created');
  projects.push(p);
}

app.ws('/connect', (websocket /* , request */) => {
  log.debug('A client connected!');
  sendState(websocket);
  websocket.on('message', (message) => {
    log.debug(`A client sent a message: ${message}`);
    const [messageType, ...escapedArgs] = message.split(':');
    const args = escapedArgs.map(s => s.replace(/<colon>/g, ':'));
    if (messageType === 'new-project' && args.length > 0) {
      newProject(args[0], websocket);
      sendState(websocket);
    } else if (messageType === 'grab-image') {
      const [projectId, sceneIndex, cameraUrl, cameraUser, cameraPass] = args;
      images.grabImage(cameraUrl, cameraUser, cameraPass).then((fileName) => {
        const [project] = projects.filter(p => p.id === projectId); // TODO: safety checks!
        const scene = project.scenes[sceneIndex];
        scene.images.push({ path: fileName });
        sendState(websocket);
      }, err => log.warn(`Grab failed: ${err}`));
    }
  });
});

app.listen(port, () => log.info(`Magrab server listening on port ${port}!`));
