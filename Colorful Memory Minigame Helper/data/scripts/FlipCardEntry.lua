local FlipCardEntry = {}
local CFlipCardTouch = {}
local revealing = 0
local offsetTransitionDuration = 0.5

function CFlipCardTouch:handleTouch(element)
  element.isFlipped = true
  element:StartColourTransition()
  if not element.doingRevealTest then
    local curRevealed = element:parent():parent().curRevealed
    if curRevealed < 2 and revealing ~= 1 then
      element:parent():parent().curRevealed = curRevealed + 1
      element:fuzzyWuzzyWasABear()
    end
  else
    game.playFlipcardSelectSound(element:parent():V("CardInd"):GetInt())
  end
end

local CardOffsetTransition = include("MenuElementPositionOffsetTransition")
local ColourTransition = include("MenuColorTransition")
FlipCardEntry._CFlipCardTouch = CFlipCardTouch
FlipCardEntry.cardBack = nil
FlipCardEntry.flipTimerFront = 0
FlipCardEntry.matchTimerUp = 0
FlipCardEntry.matchTimerDown = 0
FlipCardEntry.cSprite = nil
FlipCardEntry.cText = nil
FlipCardEntry.cTouch = nil
FlipCardEntry.doFadeOut = false

function FlipCardEntry:updateComponents()
  local alpha = self:V("alpha"):GetFloat()
  self.cSprite:V("alpha"):SetFloat(alpha)
end

function FlipCardEntry:InitColourTransition(duration, maxFade, delay)
  ColourTransition.OnInit(self.cSprite, {
    duration = duration,
    maxFade = maxFade,
    delayOnShow = delay or 0
  })
end

function FlipCardEntry:StartColourTransition()
  ColourTransition.Show(self.cSprite)
  self.matchTimerUp = 0
  self.matchTimerDown = 0
end

function FlipCardEntry:tickColourTransition(dt)
  ColourTransition.OnTick(self.cSprite, dt, {
     ease = function(t, b, c, d) return t / d end
    })
end

function FlipCardEntry:InitCardOffsetTransition()
  CardOffsetTransition.OnInit(self:parent(), {
    startX = self:parent():V("xOffset"):GetInt(),
    startY = self:parent():V("yOffset"):GetInt(),
    endX = self:parent():parent().boardCenterOffsetX,
    endY = self:parent():parent().boardCenterOffsetY,
    duration = offsetTransitionDuration
  })
end

function FlipCardEntry:StartCardOffsetTransition()
  self.cSprite:setColor(1, 1, 1)
  CardOffsetTransition.Show(self:parent())
  self.matchTimerUp = 0
  self.matchTimerDown = 0
end

function FlipCardEntry:tickOffset(dt)
  CardOffsetTransition.OnTick(self:parent(), dt, {
    ease = lua_sys.Cubic_EaseIn,
    onDoneShow = function(e)
      local midX = self:absX() + self:absW() / 2
      local midY = self:absY() + self:absH() / 2
      game.playFlipEmbeddedRewardParticle(midX, midY, "Tutorial", 0.001, 2 * game.windowScaleX(), 0.5)
      local amt = game.getFlipcardAmt(self:parent():V("CardInd"):GetInt())
      if amt ~= -1 then
        self.cText:V("text"):SetString(game.commaizeNumber(amt))
        self.cText:V("visible"):SetInt(1)
      end
      self:parent():parent():onDoneEndLevelCardOffset(self:parent():V("CardInd"):GetInt())
    end
  })
end

function FlipCardEntry:onInit()
  self:V("flipTimerBack"):SetFloat(0)
  self.doingRevealTest = false
  self.cSprite = self:C("Sprite")
  self.cText = self:C("Text")
  self.cTouch = self:C("Touch")
  self.updateComponents = FlipCardEntry.updateComponents
  self.InitColourTransition = FlipCardEntry.InitColourTransition
  self.StartColourTransition = FlipCardEntry.StartColourTransition
  self.tickColourTransition = FlipCardEntry.tickColourTransition
  self.StartCardOffsetTransition = FlipCardEntry.StartCardOffsetTransition
  self.doFadeOut = game.flipCardFadeCard(self:parent():V("CardInd"):GetInt())
  self.cTouch.onTouchUp = CFlipCardTouch.handleTouch
  self:InitCardOffsetTransition()
  self.isFlipped = false
  -- prepare fade to normal
  self:InitColourTransition(1.5, 1, 1)
end

function FlipCardEntry:onTick(dt)
  local timer = self:V("flipTimerBack"):GetFloat()
  local scaleFactor = self:parent():V("ScaleFactor"):GetFloat()
  if 0 < timer then
    timer = timer - dt
    if timer <= 0 then
      timer = 0
      self.flipTimerFront = 0.1
      self.cSprite:V("spriteName"):SetString(self.cardBack)
    end
    self:setScale(lua_sys.Vector2(scaleFactor * (timer / 0.1), scaleFactor))
  end
  self:V("flipTimerBack"):SetFloat(timer)
  timer = self.flipTimerFront
  if 0 < timer then
    timer = timer - dt
    if timer <= 0 then
      timer = 0
      if revealing == 1 then
        game.playFlipcardSelectSound(self:parent():V("CardInd"):GetInt())
        if not self.doingRevealTest then
          game.selectCard(self)
        end
      else
        self.cTouch:V("enabled"):SetInt(1)
      end
    end
    self:setScale(lua_sys.Vector2(scaleFactor * (1 - timer / 0.1), scaleFactor))
  end
  self.flipTimerFront = timer
  timer = self.matchTimerUp
  if 0 < timer then
    timer = timer - dt
    if timer <= 0 then
      timer = 0
      self.matchTimerDown = 0.1
    end
    self:setScale(lua_sys.Vector2(scaleFactor + (1 - timer / 0.2) * scaleFactor * 0.1, scaleFactor + (1 - timer / 0.2) * scaleFactor * 0.1))
  end
  self.matchTimerUp = timer
  timer = self.matchTimerDown
  if 0 < timer then
    timer = timer - dt
    if timer <= 0 then
      timer = 0
    end
    local newGrey = 0.6 + timer / 0.2 * 0.4
    self:setScale(lua_sys.Vector2(scaleFactor + timer / 0.2 * scaleFactor * 0.1, scaleFactor + timer / 0.2 * scaleFactor * 0.1))
  end
  self.matchTimerDown = timer
  self:tickOffset(dt)

  -- apply color (first calculated in HSV for brighter colors)
  if self.isFlipped then
    -- update tick function from the imported 'MenuColorTransition' library
    self:tickColourTransition(dt)
  else
    -- apply random color
    local str = "" .. game.getFlipcardImg(self:parent():V("CardInd"):GetInt())
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2147483647
    end

    -- Generate evenly distributed hue
    local h = (hash * 0.61803398875 % 1) * 360

    -- Fixed vivid saturation/value
    local s = 0.85
    local v = 0.95

    -- HSV -> RGB
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c

    local r, g, b

    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    self.cSprite:V("red"):SetFloat(r + m)
    self.cSprite:V("green"):SetFloat(g + m)
    self.cSprite:V("blue"):SetFloat(b + m)
  end
end

function FlipCardEntry:fuzzyWuzzyWasABear()
  if self:V("flipTimerBack"):GetFloat() == 0 and self.flipTimerFront == 0 then
    self:V("flipTimerBack"):SetFloat(0.1)
    self.cardBack = "gfx/breeding/" .. game.getFlipcardImg(self:parent():V("CardInd"):GetInt())
    revealing = 1
  end
end

function FlipCardEntry:someCrapTest()
  self.doingRevealTest = true
  self:fuzzyWuzzyWasABear()
end

function FlipCardEntry:conceal()
  if self:V("flipTimerBack"):GetFloat() == 0 and self.flipTimerFront == 0 then
    self:V("flipTimerBack"):SetFloat(0.1)
    self.cardBack = "gfx/breeding/monster_portrait_random"
    revealing = 0
    self.isFlipped = false
  end
end

function FlipCardEntry:match()
  self:parent():parent().curRevealed = 0
  self.matchTimerUp = 0.2
  game.playEffect("particles/FX_MatchGame_Match.efkefc", self.cSprite:absX() + self.cSprite:absW() * 0.5, self.cSprite:absY() + self.cSprite:absH() * 0.5, self.cSprite("layer"):GetString(), 0.001, 16 * self:parent():V("ScaleFactor"):GetFloat())
end

return FlipCardEntry
