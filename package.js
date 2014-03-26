Package.describe({
  summary: "Save a webcam image to the user's profile"
});

Package.on_use(function (api) {
  api.use([
    'coffeescript',
    'deps',
    'jquery',
    'session',
    'templating'
  ], 'client');

  api.add_files([
    'client/views/get_image.html',
    'client/views/get_image.coffee',
  ], 'client');
});

