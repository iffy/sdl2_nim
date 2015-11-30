# ex203_blending.nim
# ==================
# VIDEO / Blending modes
# ----------------------


import sdl2/sdl, sdl2/sdl_image as img


const
  Title = "SDL2 App"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0
  RendererFlags = sdl.RendererAccelerated or sdl.RendererPresentVsync


type
  App = ref AppObj
  AppObj = object
    window*: sdl.Window # Window pointer
    renderer*: sdl.Renderer # Rendering state pointer


  Image = ref ImageObj
  ImageObj = object of RootObj
    texture: sdl.Texture # Image texture
    w, h: int # Image dimensions


#########
# IMAGE #
#########

proc newImage(): Image = Image(texture: nil, w: 0, h: 0)
proc free(obj: Image) = sdl.destroyTexture(obj.texture)
proc w(obj: Image): int {.inline.} = return obj.w
proc h(obj: Image): int {.inline.} = return obj.h

# blend
proc blend(obj: Image): sdl.BlendMode =
  var blend: sdl.BlendMode
  if obj.texture.getTextureBlendMode(addr(blend)) == 0:
    return blend
  else:
    return sdl.BlendModeBlend

proc `blend=`(obj: Image, mode: sdl.BlendMode) {.inline.} =
  discard obj.texture.setTextureBlendMode(mode)

# alpha
proc alpha(obj: Image): int =
  var alpha: uint8
  if obj.texture.getTextureAlphaMod(addr(alpha)) == 0:
    return alpha
  else:
    return 255

proc `alpha=`(obj: Image, alpha: int) =
  discard obj.texture.setTextureAlphaMod(alpha.uint8)


# Load image from file
# Return true on success or false, if image can't be loaded
proc load(obj: Image, renderer: sdl.Renderer, file: string): bool =
  result = true
  # Load image to texture
  obj.texture = renderer.loadTexture(file)
  if obj.texture == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't load image %s: %s",
                    file, img.getError())
    return false
  # Get image dimensions
  var w, h: cint
  if obj.texture.queryTexture(nil, nil, addr(w), addr(h)) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't get texture attributes: %s",
                    sdl.getError())
    sdl.destroyTexture(obj.texture)
    return false
  obj.w = w
  obj.h = h


# Render texture to screen
proc render(obj: Image, renderer: sdl.Renderer, x, y: int): bool =
  var rect = sdl.Rect(x: x, y: y, w: obj.w, h: obj.h)
  if renderer.renderCopy(obj.texture, nil, addr(rect)) == 0:
    return true
  else:
    return false


# Render transformed texture to screen
proc renderEx(obj: Image, renderer: sdl.Renderer, x, y: int,
              w = 0, h = 0, angle = 0.0, centerX = -1, centerY = -1,
              flip = sdl.FlipNone): bool =
  var
    rect = sdl.Rect(x: x, y: y, w: obj.w, h: obj.h)
    centerObj = sdl.Point(x: centerX, y: centerY)
    center: ptr sdl.Point = nil
  if w != 0: rect.w = w
  if h != 0: rect.h = h
  if not (centerX == -1 and centerY == -1): center = addr(centerObj)
  if renderer.renderCopyEx(obj.texture, nil, addr(rect),
                           angle, center, flip) == 0:
    return true
  else:
    return false


##########
# COMMON #
##########

# Initialization sequence
proc init(app: App): bool =
  # Init SDL
  if sdl.init(sdl.InitVideo) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL: %s",
                    sdl.getError())
    return false

  # Init SDL_Image
  if img.init(img.InitPng) == 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_Image: %s",
                    img.getError())

  # Create window
  app.window = sdl.createWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW,
    ScreenH,
    WindowFlags)
  if app.window == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create window: %s",
                    sdl.getError())
    return false

  # Create renderer
  app.renderer = sdl.createRenderer(app.window, -1, RendererFlags)
  if app.renderer == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create renderer: %s",
                    sdl.getError())
    return false

  # Set draw color
  if app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0xFF) != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't set draw color: %s",
                sdl.getError())
    return false

  sdl.logInfo(sdl.LogCategoryApplication, "SDL initialized successfully")
  return true


# Shutdown sequence
proc exit(app: App) =
  app.renderer.destroyRenderer()
  app.window.destroyWindow()
  img.quit()
  sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


# Event handling
# Return true on app shutdown request, otherwise return false
proc events(pressed: var seq[sdl.Keycode]): bool =
  result = false
  var e: sdl.Event
  if pressed != nil:
    pressed = @[]

  while sdl.pollEvent(addr(e)) != 0:

    # Quit requested
    if e.kind == sdl.Quit:
      return true

    # Key pressed
    elif e.kind == sdl.KeyDown:
      # Add pressed key to sequence
      if pressed != nil:
        pressed.add(e.key.keysym.sym)

      # Exit on Escape key press
      if e.key.keysym.sym == sdl.K_Escape:
        return true


########
# MAIN #
########

var
  app = App(window: nil, renderer: nil)
  done = false # Main loop exit condition
  pressed: seq[sdl.Keycode] = @[] # Pressed keys

if init(app):

  # Load assets
  var
    image1 = newImage()
    image2 = newImage()
  if not image1.load(app.renderer, "img/img1.png"):
    done = true
  if not image2.load(app.renderer, "img/img2.png"):
    done = true

  echo "-----------------------"
  echo "|      Controls:      |"
  echo "|---------------------|"
  echo "| Q/A: change width   |"
  echo "| W/S: change height  |"
  echo "| E/D: rotate         |"
  echo "| R/F: flip           |"
  echo "| Z/X/C/V: blend mode |"
  echo "| T/G: change alpha   |"
  echo "-----------------------"

  # Transformations
  const
    sizeStep = 10
    angleStep = 10
    alphaStep = 8
  var
    w = image1.w
    h = image1.h
    angle = 0.0
    flip = sdl.FlipNone
    alpha = 255

  # Main loop
  while not done:
    # Clear screen with draw color
    if app.renderer.renderClear() != 0:
      sdl.logWarn(sdl.LogCategoryVideo,
                  "Can't clear screen: %s",
                  sdl.getError())

    # Render textures
    if not image2.renderEx(app.renderer, 0, 0, 300, 300):
      sdl.logWarn(sdl.LogCategoryVideo,
                  "Can't render image2: %s",
                  sdl.getError())
    if not image1.renderEx(app.renderer,
                           ScreenW div 2 - w div 2,
                           ScreenH div 2 - h div 2,
                           w, h, angle, flip = flip):
      sdl.logWarn(sdl.LogCategoryVideo,
                  "Can't render image1: %s",
                  sdl.getError())

    # Update renderer
    app.renderer.renderPresent()

    # Enent handling
    done = events(pressed)

    # Process input
    if K_q in pressed: w += sizeStep
    if K_a in pressed: w -= sizeStep
    if K_w in pressed: h += sizeStep
    if K_s in pressed: h -= sizeStep
    if K_e in pressed: angle += angleStep
    if K_d in pressed: angle -= angleStep
    if K_r in pressed:
      if flip == sdl.FlipNone:
        flip = sdl.FlipHorizontal
      else:
        flip = sdl.FlipNone
    if K_f in pressed:
      if flip == sdl.FlipNone:
        flip = sdl.FlipVertical
      else:
        flip = sdl.FlipNone
    if K_z in pressed: image1.blend = BlendModeNone
    if K_x in pressed: image1.blend = BlendModeBlend
    if K_c in pressed: image1.blend = BlendModeAdd
    if K_v in pressed: image1.blend = BlendModeMod
    if K_t in pressed: alpha += alphaStep
    if K_g in pressed: alpha -= alphaStep

    # Check bounds
    if w <= 0: w = sizeStep
    if h <= 0: h = sizeStep
    if angle >= 360: angle -= 360
    elif angle <= -360: angle += 360
    if alpha < 0: alpha = 0
    if alpha > 255: alpha = 255

    # Set alpha value
    image1.alpha = alpha

  # Free assets
  free(image1)
  free(image2)

# Shutdown
exit(app)

