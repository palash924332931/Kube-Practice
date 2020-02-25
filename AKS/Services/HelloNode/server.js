'use strict';
var http = require('http');
var fs = require('fs');
var port = process.env.PORT || 80;

http.createServer(function (req, res) {
    
    // res.writeHead(200, { 'Content-Type': 'text/html' });
    // res.send('<h1>Hello World</h1>');

    res.writeHead(200, { 'Content-Type': 'text/html' });
    //res.end('okay');

    // res.writeHead(200, { 'Content-Type': 'application/json' });
    // res.end('{ "message": "Hello World from Node.js", "port": ' + port + ' }');

    
  var file = fs.createReadStream('index.html');
  file.pipe(res);

}).listen(port, () => {
    console.log('started on port: ' + port);
});