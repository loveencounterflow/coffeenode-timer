
############################################################################################################
TRM                       = require 'coffeenode-trm'
TIMER                     = require '..'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
after                     = suspend.after
eventually                = process.nextTick

#-----------------------------------------------------------------------------------------------------------
test = ->
  step ( resume ) ->*
    TIMER.new()
    TIMER.new 'helo world'
    # log TRM.green timer = TIMER.start()
    #.......................................................................................................
    timer = TIMER.new 'simple random timeout'
    for idx in [ 0 .. 8 ]
      do ( idx ) ->
        TIMER.start timer, idx
        after 1 + ( 1 - Math.random() * 2 ), ->
          TIMER.stop timer, idx #if idx % 3 is 0
          # if ( TIMER.count_pending_runs timer ) is 0
          #   TIMER._set_delta_times timer
          #   log TRM.pink TIMER._format_time time for time in timer[ 'delta-times' ]
    # log timer
    # TIMER.log_report()

############################################################################################################
CARRIER = {}

#-----------------------------------------------------------------------------------------------------------
CARRIER.sync_method = ->
  x = 0
  for n in [ 0 .. 1000000 ]
    x += 1
  return null

#-----------------------------------------------------------------------------------------------------------
CARRIER.async_method = ( handler ) ->
  route = '../package.json'
  ( require 'fs' ).readFile route, -> return handler null, null



############################################################################################################
# do test

append = ( P... ) ->
  ( require 'fs' ).appendFileSync '/tmp/log.txt', ( TRM.pen P... ), encoding: 'utf-8'

process.on 'exit', ->
  append '(title)'
  # append TRM.remove_colors TIMER.report()
  append TIMER.report()

CARRIER.sync_method   = TIMER.sync_instrumentalize  'sync_method',  CARRIER.sync_method.bind  CARRIER
CARRIER.async_method  = TIMER.async_instrumentalize 'async_method', CARRIER.async_method.bind CARRIER

for n in [ 0 ... 10 ]
  CARRIER.sync_method()

for n in [ 0 ... 20 ]
  CARRIER.async_method ( error, result ) ->


