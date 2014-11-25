/* Server.js: Simply a mirror to pull in the actual app, as many deployment services have trouble with starting coffeescript directly. */

require('coffee-script');
require('./app').run();