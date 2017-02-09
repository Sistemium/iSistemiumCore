const HandlebarsGenerator = require('handlebars-generator');
const dir = require('node-dir');

const options = {
    sourceExtension: 'hb',
    distExtension: 'm'
};

const templates = 'templates';

const root = `${__dirname}/${templates}`;

dir.paths(root, function(err, paths) {

    if (err) throw err;

    paths.dirs.forEach(directory => {

        let ignoreRe = /[^\/]+$/;

        let folder = directory.match(ignoreRe)[0];

        if (folder[0] === '.') return;

        folder = directory.replace(root, '');

        let destination = `${__dirname}/${folder}`;

        HandlebarsGenerator.generateSite(directory, destination, options)
            .then(function () {
                console.log('successfully generated pages for', folder);
            }, function (e) {
                console.error('failed to generate pages', e);
            });
    });

});
