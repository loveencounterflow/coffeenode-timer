
############################################################################################################
TIMER = @

suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
after                     = suspend.after

test = ->
  step ( resume ) ->*
    TIMER.new_timer()
    TIMER.new_timer 'helo world'
    # log TRM.green timer = TIMER.start()
    #.......................................................................................................
    timer = TIMER.new_timer 'simple random timeout'
    for idx in [ 0 .. 8 ]
      do ( idx ) ->
        TIMER.start timer, idx
        after 2 + ( 2 - Math.random() * 4 ), ->
          TIMER.stop timer, idx #if idx % 3 is 0
          # if ( TIMER.count_pending_runs timer ) is 0
          #   TIMER._set_delta_times timer
          #   log TRM.pink TIMER._format_time time for time in timer[ 'delta-times' ]
    # log timer
    # TIMER.log_report()

do test
