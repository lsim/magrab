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

function makeProject(fileName) {
  return {
    name: 'Server project',
    id: 'the-id',
    scenes: [
      {
        name: 'Scene 1',
        images: [
          { path: fileName },
        ],
      },
      {
        name: 'Scene 2',
        images: [],
      },
    ],
  };
}

app.ws('/connect', (websocket /* , request */) => {
  console.log('A client connected!');

  websocket.on('message', (message) => {
    console.log(`A client sent a message: ${message}`);
    if (message === 'grab-image') {
      images.grabImage().then((fileName) => {
        websocket.send(JSON.stringify(makeProject(fileName)));
      }, err => console.log(`Grab failed ${err}`));
    }
  });
});

app.listen(port, () => console.log(`Magrab server listening on port ${port}!`));
