basename = require('path').basename
exec = require('child_process').exec
platform = require('process').platform
grammarMap = require('./grammar-map')
filenameMap = require('./filename-map')

plugin = module.exports =
  # Use an empty config by default since Atom fails to populate the settings
  # view corretly with pre-defined properties.
  config:
    grammars:
      type: 'object'
      properties: {}
    filenames:
      type: 'object'
      properties: {}

  # Override `exec` for testing.
  exec: exec

  activate: () ->
    atom.commands.add('atom-text-editor', {
      'dash:shortcut': () => @shortcut(true, false),
      'dash:shortcut-background': () => @shortcut(true, true),
      'dash:shortcut-alt': () => @shortcut(false, false),
      'dash:shortcut-alt-background': () => @shortcut(false, true),
      'dash:context-menu': () => @shortcut(true, false)
    })

  shortcut: (sensitive, background) ->
    editor = atom.workspace.getActiveTextEditor()

    return if !editor

    selection = editor.getLastSelection().getText()

    if selection
      return plugin.search(selection, sensitive, background)

    return plugin.search(editor.getWordUnderCursor(), sensitive, background)

  search: (string, sensitive, background, cb) ->
    activeEditor = atom.workspace.getActiveTextEditor()

    if sensitive and activeEditor
      path = activeEditor.getPath()
      language = activeEditor.getGrammar().name

    cmd = @getCommand(string, path, language, background)

    # Exec is used because spawn escapes arguments that contain double-quotes
    # and replaces them with backslashes. This interferes with the ability to
    # properly create the child process in windows, since windows will barf
    # on an ampersand that is not contained in double-quotes.
    plugin.exec(cmd, cb)

  getCommand: (string, path, language, background) ->
    if platform == 'win32'
      return 'cmd.exe /c start "" "' + @getDashURI(string, path, language, background) + '"'

    if platform == 'linux'
      return @getZealCommand(string, path, language, background)

    return 'open -g "' + @getDashURI(string, path, language, background) + '"'

  getKeywordString: (path, language) ->
    keys = []

    if path
      filename = basename(path).toLowerCase()
      filenameConfig = atom.config.get('dash.filenames') || {}
      keys = keys.concat(filenameConfig[filename] || filenameMap[filename] || [])

    if language
      grammarConfig = atom.config.get('dash.grammars') || {}
      keys = keys.concat(grammarConfig[language] || grammarMap[language] || [])

    return keys.map(encodeURIComponent).join(',') if keys.length

  getDashURI: (string, path, language, background) ->
    link = 'dash-plugin://query=' + encodeURIComponent(string)
    keywords = @getKeywordString(path, language)

    if keywords
      link += '&keys=' + keywords

    if background
      link += '&prevent_activation=true'

    return link

  # TODO(blakeembrey): If someone knows how to background Zeal on activation,
  # please open a Pull Request!
  getZealCommand: (string, path, language, background) ->
    query = string
    keywords = @getKeywordString(path, language)

    if keywords
      query = keywords + ':' + query

    return 'zeal --query "' + query + '"'
