const HandlebarsGenerator = require('handlebars-generator');
const dir = require('node-dir');
const fs = require('fs');
const _ = require('underscore');

const sourceExtension = 'hb';
const distExtension = 'm';

const options = {
    sourceExtension,
    distExtension
};

const templates = 'templates';

const root = `${__dirname}/${templates}`;

dir.subdirs(root, function(err, paths) {

    if (err) throw err;

    paths.forEach(directory => {

        const sourceExtensionRe = new RegExp(`\\.${sourceExtension}$`);

        let ignoreRe = /[^\/]+$/;

        let folder = directory.match(ignoreRe)[0];

        if (folder[0] === '.') return;

        let files = fs.readdirSync(directory);

        if (!_.find(files, file => sourceExtensionRe.test(file))) return;

        folder = directory.replace(`${root}/`, '');

        let destination = `${__dirname}/${folder}`;

        console.log ('destination:', destination);

        (new HandlebarsGenerator()).generateSite(directory, destination, options)
            .then(function () {
                console.log('successfully generated pages for', folder);
            }, function (e) {
                console.error('failed to generate pages', e);
            });
    });

});
