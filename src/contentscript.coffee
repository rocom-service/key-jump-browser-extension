HINT_CHARACTERS = '1234567890'
KEYCODE_ESC = 27
KEYCODE_RETURN = 13
TARGET_ELEMENTS = """
a[href],
input:not([disabled]):not([type=hidden]),
textarea:not([disabled]),
select:not([disabled]),
button:not([disabled]),
[contenteditable='true'],
[contenteditable]:not([contenteditable='false']),
embed + .fc-panel,
embed ~ .PlaceholderFF
"""
# Unknown input types are treated as text inputs by Chrome
# so we whitelist the ones we know can't be typed in.
#
# Only care about if the input can not be typed in
# as of the latest version of Chrome.
KNOWN_NON_TYPABLE_INPUT_TYPES = [
  'button', 'submit', 'reset', 'image',
  'checkbox', 'radio', 'range', 'color', 'file'
]
CLASSNAME_ROOT = 'KEYJUMP'
CLASSNAME_ACTIVE = 'KEYJUMP_active'
CLASSNAME_FILTERED = 'KEYJUMP_filtered'
CLASSNAME_HINT = 'KEYJUMP_hint'
CLASSNAME_MATCH = 'KEYJUMP_match'
TIMEOUT_REACTIVATE = 100
DEFAULT_OPTIONS =
  activationChar: ','
  activationShift: false
  activationCtrl: false
  activationAlt: false
  activationMeta: false
  activationTabChar: '.'
  activationTabShift: false
  activationTabCtrl: false
  activationTabAlt: false
  activationTabMeta: false
  keepHintsAfterTrigger: false

w = window
d = document
options = {}
firstActivation = true
active = false
reactivateTimeout = null
hintsRootEl = d.createElement 'div'
hintsRootEl.classList.add CLASSNAME_ROOT
hintSourceEl = d.createElement 'div'
hintSourceEl.classList.add CLASSNAME_HINT
hints = null
hintMatch = null
removeHintsTimeout = null
query = null
targetEls = null
hintWidth = 0
hintHeight = 0
hintCharWidth = 0

activate = ->
  hints = {}
  query = ''
  hintId = 0
  fragment = d.createDocumentFragment()

  if firstActivation
    d.body.appendChild hintsRootEl
    firstActivation = false

    getHintHeightEl = hintSourceEl.cloneNode true
    hintsRootEl.appendChild getHintHeightEl
    hintWidth = getHintHeightEl.offsetWidth
    getHintHeightEl.innerHTML = 0
    hintHeight = getHintHeightEl.offsetHeight
    hintCharWidth = getHintHeightEl.offsetWidth - hintWidth

  clearTimeout removeHintsTimeout
  removeHints()

  targetEls = d.querySelectorAll TARGET_ELEMENTS

  if targetEls.length
    if !active
      active = true
      d.addEventListener 'scroll', setReactivationTimeout, false
      w.addEventListener 'popstate', setReactivationTimeout, false
      w.addEventListener 'resize', setReactivationTimeout, false
  else return

  for target in targetEls
    if isElementVisible target
      hintId++
      hints[hintId] =
        id: hintId
        el: hintSourceEl.cloneNode true
        target: target

  for hintKey, hint of hints
    hintKey = hintKey.toString()
    hint.el.setAttribute 'data-hint-id', hintKey
    hint.el.innerHTML = hintKey
    fragment.appendChild hint.el
    targetPos = getElementPos(hint.target)
    top = Math.max(
      d.body.scrollTop,
      Math.min(
        Math.round(targetPos.top),
        (w.innerHeight + d.body.scrollTop) - hintHeight
      )
    )
    left = Math.max(0, Math.round(targetPos.left) - hintWidth - (hintCharWidth * hintKey.length) - 2)
    hint.el.style.top = top + 'px'
    hint.el.style.left = left + 'px'

  hintsRootEl.appendChild fragment
  hintsRootEl.classList.add CLASSNAME_ACTIVE

  return

deactivate = ->
  if !active then return
  d.removeEventListener 'scroll', setReactivationTimeout, false
  w.removeEventListener 'popstate', setReactivationTimeout, false
  w.removeEventListener 'resize', setReactivationTimeout, false
  clearTimeout reactivateTimeout
  timeoutDuration = parseFloat(w.getComputedStyle(hintsRootEl).transitionDuration) * 1000
  active = false
  hints = null
  hintMatch = null
  hintsRootEl.classList.remove CLASSNAME_ACTIVE
  removeHintsTimeout = setTimeout removeHints, timeoutDuration
  query = null
  return

appendToQuery = (event) ->
  char = String.fromCharCode event.keyCode
  if HINT_CHARACTERS.indexOf(char) > -1
    stopKeyboardEvent event
    if hints[query + char]
      query += char
      filterHints()
  return

filterHints = ->
  hintMatch = hints[query]
  hintsRootEl.classList[if query then 'add' else 'remove'] CLASSNAME_FILTERED
  for el in hintsRootEl.querySelectorAll '.' + CLASSNAME_MATCH
    el.classList.remove CLASSNAME_MATCH
  if query
    for el in hintsRootEl.querySelectorAll '[data-hint-id^="' + query + '"]'
      el.classList.add CLASSNAME_MATCH
  return

removeHints = ->
  hintsRootEl.removeChild hintsRootEl.firstChild while hintsRootEl.firstChild
  hintsRootEl.classList.remove CLASSNAME_FILTERED

triggerHintMatch = (event) ->
  target = hintMatch && hintMatch.target
  return if !target
  tagName = target.tagName.toLocaleLowerCase()
  mouseEventType = if tagName == 'select' then 'mousedown' else 'click'
  if shouldFocusElement target
    target.focus()
  else
    clickEvent = new MouseEvent mouseEventType,
      view: window
      bubbles: true
      cancelable: true
      shiftKey: event.shiftKey
      ctrlKey:  event.ctrlKey
      altKey:   event.altKey
      metaKey:  event.metaKey
    target.dispatchEvent clickEvent
  if options.keepHintsAfterTrigger
    activate()
  else deactivate()
  return

canTypeInElement = (el) ->
  return if !el
  tagName = el.tagName.toLocaleLowerCase()
  inputType = el.getAttribute 'type'
  el.contentEditable == 'true' ||
    tagName == 'textarea' ||
    (tagName == 'input' && inputType not in KNOWN_NON_TYPABLE_INPUT_TYPES)

shouldFocusElement = (el) ->
  return if !el
  tagName = el.tagName.toLocaleLowerCase()
  inputType = el.getAttribute 'type'
  canTypeInElement el  || (tagName == 'input' && inputType == 'range')

getElementPos = (el) ->
  rect = el.getClientRects()[0]
  return if !rect
  scrollTop = window.scrollY
  scrollLeft = window.scrollX
  return {
    top: rect.top + scrollTop
    bottom: rect.bottom + scrollTop
    right: rect.right + scrollLeft
    left: rect.left + scrollLeft
  }

isElementVisible = (el) ->
  rect = el.getClientRects()[0]
  if !rect ||
    rect.width <= 0 ||
    rect.height <= 0 ||
    rect.top >= w.innerHeight ||
    rect.left >= w.innerWidth ||
    rect.bottom <= 0 ||
    rect.right <= 0
      return false
  while el
    styles = w.getComputedStyle el
    if styles.display == 'none' ||
      styles.visibility == 'hidden' ||
      styles.opacity == '0'
        return false
    el = el.parentElement
  true

getCharacterFromEvent = (event) ->
  JSON.parse('"' + (event.keyIdentifier).replace('U+', '\\u') + '"').toLowerCase()

isActivationKey = (event) ->
  getCharacterFromEvent(event) == options.activationChar &&
    event.shiftKey == options.activationShift &&
    event.ctrlKey == options.activationCtrl &&
    event.altKey == options.activationAlt &&
    event.metaKey == options.activationMeta

isActivationTabKey = (event) ->
  getCharacterFromEvent(event) == options.activationTabChar &&
    event.shiftKey == options.activationTabShift &&
    event.ctrlKey == options.activationTabCtrl &&
    event.altKey == options.activationTabAlt &&
    event.metaKey == options.activationTabMeta

handleKeydownEvent = (event) ->
  hasModifier = event.shiftKey || event.ctrlKey || event.altKey || event.metaKey
  if !canTypeInElement d.activeElement
    if event.keyCode == KEYCODE_RETURN && hintMatch
      # Use keyup for triggering, only prevent keydown
      stopKeyboardEvent event
    else if isActivationKey event
      if active then deactivate() else activate()
      stopKeyboardEvent event
    else if isActivationTabKey event
      console.log '"Show hints and open links in new tabs" triggered'
      if active then deactivate() else activate()
      stopKeyboardEvent event
    else if !hasModifier && active
      if event.keyCode == KEYCODE_ESC then handleEscapeEvent event
      else appendToQuery event
  return

handleKeyupEvent = (event) ->
  # Use keyup for triggering, because if we focus the target element on keydown
  # there will be a keyup event on the target element and that's annoying to deal with..
  if event.keyCode == KEYCODE_RETURN && hintMatch && !canTypeInElement d.activeElement
    stopKeyboardEvent event
    triggerHintMatch event
  return

handleEscapeEvent = (event) ->
  if query
    query = ''
    filterHints()
  else deactivate()
  stopKeyboardEvent event
  return

stopKeyboardEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()
  event.stopImmediatePropagation()
  return

setReactivationTimeout = () ->
  clearTimeout reactivateTimeout
  reactivateTimeout = setTimeout activate, TIMEOUT_REACTIVATE
  return

# Init

chrome.storage.sync.get Object.keys(DEFAULT_OPTIONS), (storageOptions) ->
  for own key, value of DEFAULT_OPTIONS
    options[key] = if storageOptions.hasOwnProperty key then storageOptions[key] else value
  return

d.addEventListener 'keydown', handleKeydownEvent, true
d.addEventListener 'keyup', handleKeyupEvent, true
