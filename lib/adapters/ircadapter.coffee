
# **************************************************************************
#
## IRCAdapter
#
# **************************************************************************
#
## Interface Method Requirements:
#   - setsocket(socket)
#   - connect(data)
#   - disconnect()
#   - join(data)
#   - message(data)
#
## Client socket messages:
#   These are event messages that are used to communicate with the client.
#   - (see SERVICE:LISTENERS below)
#
## Backend socket messages:
#   - this.emit('REGISTERED')
#     - Use this only after a successful connection to let the
#       ClientsManager know to clear it's queued call stack
#
#
## Interface Property Requirements:
#   - id: string
#   - isConnected: boolean
#
# **************************************************************************

IRC          = require("irc")
net          = require("net")
EventEmitter = require('events').EventEmitter

class IRCAdapter extends EventEmitter
  io: null
  socket: null
  id: null

  server: null
  port: null
  nick: null
  channels: null
  isConnected: false

  debug: false

  constructor: (socket, id) ->
    console.log("IRCAdapter") unless @debug?
    @id = id
    @socket = socket

  setSocket: (socket) ->
    @socket = socket


  connect: (data) ->
    console.log ">>>>>", data
    @server = data.server
    @port = data.port
    @nick = data.nick
    @channels = data.channels if data.channels?

    @io = new IRC.Client @server, @nick,
      showErrors: @debug
      debug: @debug
      port: @port
      channels: @channels



    # **************************************************************************
    #
    ## SERVICE:LISTENERS
    #
    # **************************************************************************
    #
    ## Description:
    #   Service Listeners are listening to the adapter service only. In this
    #   case, IRC. After intercepting a message from the service, you  will
    #   need to emit a message on the socket (to the client) which will
    #   inform it to react.
    #
    ## Available outgoing messages
    #   - this.socket.emit('CONNECTED', connection)
    #   - this.socket.emit("MESSAGE", payload)
    #   - this.socket.emit("NICK", payload)
    #   - this.socket.emit("JOIN", payload)
    #   - this.socket.emit("PART", payload)
    #   - this.socket.emit("QUIT", payload)
    #   - this.socket.emit("NAMES", payload)
    #   - this.socket.emit("YOUARE", payload)
    #
    # **************************************************************************

    #
    # SERVICE:LISTENER::registered
    @io.addListener "registered", (message) =>
      console.log "<< IRCAdapter::<registered>"
      connection =
        server: @server
        port: @port
        nick: @nick
        channels: @channels
      @socket.emit("CONNECTED", connection)

      @isConnected = true
      this.emit "REGISTERED"

    #
    # SERVICE:LISTENER::message
    @io.addListener "message", (nick, to, text, message) =>
      console.log "<< IRCAdapter::<message>", nick, to, text
      payload =
        nick: nick
        message: text
        channel: to
      @socket.emit "MESSAGE", payload

    #
    # SERVICE:LISTENER::join
    @io.addListener "join", (channel, nick, message) =>
      console.log "<< IRCAdapter::<join>", channel, nick, message
      payload =
        nick: nick
        channel: channel
        message: message
      @socket.emit "JOIN", payload

    #
    # SERVICE:LISTENER::part
    @io.addListener "part", (channel, nick, message) =>
      console.log "<< IRCAdapter::<part>", channel, nick, message
      payload =
        nick: nick
        channel: channel
        message: message
      @socket.emit "PART", payload

    #
    # SERVICE:LISTENER::quit
    @io.addListener "quit", (nick, reason, channels, message) =>
      console.log "<< IRCAdapter::<quit>", nick, reason, channels, message
      @socket.emit "QUIT"

    #
    # SERVICE:LISTENER::kick
    @io.addListener "kick", (channel, nick, byNick, reason, message) =>
      console.log "<< IRCAdapter::<kick>", channel, nick, byNick, reason, message
      @socket.emit "KICK"

    #
    # SERVICE:LISTENER::nick
    @io.addListener "nick", (oldnick, newnick, channels, message) =>
      console.log "<< IRCAdapter::<nick>", oldnick, newnick, channels, message
      payload =
        oldnick: oldnick
        newnick: newnick
        channels: channels
        message: message
      @socket.emit "NICK", payload

    #
    # SERVICE:LISTENER::names
    @io.addListener "names", (channel, nicks) =>
      console.log "<< IRCAdapter::<names>"
      payload =
        channel: channel
        nicks: nicks
      @socket.emit "NAMES", payload

    #
    # SERVICE:LISTENER::raw
    @io.addListener "raw", (message) =>
      # console.log "<< IRCAdapter::<raw>"
      # @eventsHandler(message)

  disconnect: -> @io.disconnect()

  whoAmI: ->
    console.log "> whoAmiI: "
    payload =
      server: @io.opt.server
      nick: @io.nick
      userName: @io.opt.userName
      realName: @io.opt.realName
      channels: @getChannels()
    @socket.emit "YOUARE", payload

  refresh: -> @getChannels()

  join: (data) ->
    console.log "IRCAdapter::join (data) ->"
    io = @io
    for channel in data.channels
      io.join(channel)

  setNick: (data) ->
    @io.send("NICK", data.nick)

  getChannels: -> return @io.chans

  getNames: (data) ->
    console.log "getNames", data
    @io.send("NAMES", data.channel)

  message: (data) ->
    console.log "IRCAdapter::message (data) ->", data
    @io.say(data.channel, data.message)

  eventsHandler: (data) ->
    command = data.command

    # console.log "  [RAW] COMMAND: ", command

    switch command
      when "JOIN"
        @socket.emit "JOIN", {nick: data.nick, channels: data.args}
      when "PRIVMSG"
        # console.log data
        payload =
          nick: data.nick
          message: data.args.splice(1)[0]
          channel: data.args.shift()
        @socket.emit "MESSAGE", payload
      else
        "poop"

module.exports = IRCAdapter
