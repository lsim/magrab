#!/usr/bin/env node
/* eslint-disable no-console */

const express = require('express');
const expressWS = require('express-ws');

const app = express();

expressWS(app);

const port = 3000;

app.get('/', (req, res) => res.send('Hello World!'));

app.use(express.static('src/client'));

app.ws('/connect', (websocket /* , request */) => {
  console.log('A client connected!');

  websocket.on('message', (message) => {
    console.log(`A client sent a message: ${message}`);
    websocket.send('Hello, world!');
  });
});

app.listen(port, () => console.log(`Magrab server listening on port ${port}!`));
