#!/usr/bin/env node
/* eslint-disable no-console */

const express = require('express');
const expressWS = require('express-ws');
const images = require('./images');

const app = express();

expressWS(app);

const port = 3000;

app.get('/', (req, res) => res.send('Hello World!'));

app.use(express.static('./src/client'));
app.use(express.static('./images'));

const projects = [];

function sendState(ws) {
  ws.send(JSON.stringify(projects));
}

function newProject(name) {
  const p = {
    name,
    id: projects.length.toString(), // TODO: could be GUID
    scenes: [
      {
        name: 'Scene 1',
        images: [
          { path: 'image.jpg' },
        ],
      },
    ],
  };
  projects.push(p);
}

app.ws('/connect', (websocket /* , request */) => {
  console.log('A client connected!');
  sendState(websocket);
  websocket.on('message', (message) => {
    console.log(`A client sent a message: ${message}`);
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
      }, err => console.log(`Grab failed ${err}`));
    }
  });
});

app.listen(port, () => console.log(`Magrab server listening on port ${port}!`));
