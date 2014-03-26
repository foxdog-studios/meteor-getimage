IMAGE_WIDTH = 640
IMAGE_HEIGHT = 480
IMAGE_MIME = 'image/png'

Template.getImage.rendered = ->
  # 1) Make sure this is only run once per template instance.
  return if @_alreadyCalled?
  @_alreadyCalled = true

  # 2) Create a canvas to use as a place to resize the user's
  #    photograph.
  @_canvas = document.createElement 'canvas'
  @_canvas.width = IMAGE_WIDTH
  @_canvas.height = IMAGE_HEIGHT
  @_ctx = @_canvas.getContext '2d'

  # 3) Video element to show the user their webcam strem.
  @_video = @find 'video'

  # 4) Hide the webcam stream once the user has taken a photograph and
  #    we're waiting for the user to accept it.
  $video = $(@_video)
  @_hideVideo = Deps.autorun ->
    if Session.get('photograph')?
      $video.hide()
    else
      $video.show()

  # 5) Take a photograph when the user clicks the video stream.
  @_stream = null
  @_takePhotograph = (event) =>
    event.preventDefault()
    return unless @_stream?
    @_updatePhotoFromImage(@_video)

  @_updatePhotoFromImage = (image) =>
    @_ctx.drawImage image, 0, 0, @_canvas.width, @_canvas.height
    Session.set 'photograph', @_canvas.toDataURL IMAGE_MIME

  @_video.addEventListener 'click', @_takePhotograph, false

  # 6) Request and, if allowed, start streaming the user's webcam.
  return unless Session.get 'hasGetUserMedia'
  options =
    video: true,
    audio: false
  successCallback = (stream) =>
    # The user could allow the stream after they have left the webcam select
    # template, so test if the video exists, if it doesn't close the stream
    # and return.
    unless @_video?
      stream.stop()
      return
    @_stream = stream
    @_video.src = window.URL.createObjectURL stream
  errorCallback = (error) ->
    console.warn "Failed to start video stream: #{ error }"
    Session.set 'hasGetUserMedia', false
  navigator.getUserMedia options, successCallback, errorCallback

Template.getImage.helpers
  hasGetUserMedia: ->
    Session.get 'hasGetUserMedia'

  photograph: ->
    Session.get 'photograph'

setTurnipImage = (template, callback) ->
  image = new Image
  image.src = 'turnip.jpg'
  image.onload = ->
    callback(image)

Template.getImage.events
  'click [name="ok"]': (event, template) ->
    event.preventDefault()
    updateUserImage template._ctx

  'click [name="retake"]': (event, template) ->
    event.preventDefault()
    Session.set 'photograph'

  'click [name="turnip"]': (event, template) ->
    event.preventDefault()
    setTurnipImage template, (image) =>
      template._updatePhotoFromImage image

  'click [name="turnip-ok"]': (event, template) ->
    event.preventDefault()
    setTurnipImage template, (image) =>
      Meteor.setTimeout ->
        template._updatePhotoFromImage image
        updateUserImage template._ctx
      , 0


Template.getImage.destroyed = ->
  # Clear session variables used by only this template
  Session.set 'photograph'

  # Desctruct everything we did in rendered in reverse order.

  # 6) Make sure the user's webcam is deactivated.
  if @_stream?
    @_stream.stop()
    delete @_stream

  # 5) Remove the click listener from the video element an
  @_video.removeEventListener 'click', @_takePhotograph, false

  # 4) Stop hiding and showing the webcam stream.
  @_hideVideo.stop()
  delete @_hideVideo

  # Allow objects referenced in 3, 2, and 1 to be garabage collected.
  delete @_video
  delete @_ctx
  delete @_canvas
  delete @_alreadyCalled

updateUserImage = (wCtx) ->
  # The canvas containing the whole photograph.
  wCanvas = wCtx.canvas

  # Width and height of the whole photograph.
  wW = wCanvas.width
  wH = wCanvas.height

  # Width and height of a cell in the grid.
  cW = wW / GRID_WIDTH
  cH = wH / GRID_HEIGHT

  # A canvas on which to create the cell images.
  cCanvas = document.createElement 'canvas'
  cCanvas.width = cW
  cCanvas.height = cH
  cCtx = cCanvas.getContext '2d'

  # Chop up the whole photograph into the cells
  cellImages =
    for y in [0...GRID_HEIGHT]
      sy = y * cH
      for x in [0...GRID_WIDTH]
        sx = x * cW
        cCtx.drawImage wCanvas, sx, sy, cW, cH, 0, 0, cW, cH
        x: x
        y: y
        image: cCanvas.toDataURL IMAGE_MIME

  # The the whole and cell images
  Meteor.users.update Meteor.userId(),
    $set:
      'profile.image': Session.get 'photograph'
      'profile.cellImages': cellImages

