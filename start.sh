(cd ./vendor/submodules/cloudsdale-faye && git checkout master && git pull --rebase && bundle && npm install && sleep 10 && node ./server.js)