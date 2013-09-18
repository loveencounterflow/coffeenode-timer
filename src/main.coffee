
############################################################################################################
njs_hrtime                = process.hrtime
#...........................................................................................................
get_stack                 = require 'coffeenode-stacktrace/lib/get-stack'
TRM                       = require 'coffeenode-trm'
TEXT                      = require 'coffeenode-text'
TYPES                     = require 'coffeenode-types'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
BIGNUMBER                 = require 'coffeenode-bignumber'


############################################################################################################
@timer_by_name          = {}
@pending_timer_count      = 0
@_hrtime_resolution       = 1e9


#===========================================================================================================
# TIMING CORE
#-----------------------------------------------------------------------------------------------------------
@now = ( me ) ->
  R = njs_hrtime()
  return BIGNUMBER.new "#{R[ 0 ]}.#{TEXT.flush_right R[ 1 ], 9, '0'}"


#===========================================================================================================
# TIMER CREATION
#-----------------------------------------------------------------------------------------------------------
@new = ( name ) ->
  name ?= @_name_from_caller_location 2 unless name?
  throw new Error "timer named #{rpr name} already in use" if @timer_by_name[ name ]?
  R =
    '~isa':         'TIMER/timer'
    'name':         name
    'start-times':  []
    'stop-times':   []
    'delta-times':  []
    'total-time':   null
    'average-time': null
    'mru-idx':      null
  #.........................................................................................................
  @timer_by_name[ name ] = R
  return R

#-----------------------------------------------------------------------------------------------------------
@_fetch_timer = ( name ) ->
  return @timer_by_name[ name ] ? @new name

#-----------------------------------------------------------------------------------------------------------
@_timer_from_arguments = ( x ) ->
  #.........................................................................................................
  if x?
    if TYPES.isa_text x
      return @_fetch_timer x
    unless ( types = TYPES.type_of x ) is 'TIMER/timer'
      throw new Error "expected a text or a timer, got a #{type}"
    return x
  #.........................................................................................................
  return @_fetch_timer @_name_from_caller_location 3

#-----------------------------------------------------------------------------------------------------------
@_name_from_caller_location = ( delta ) ->
  [ route
    line_nr
    column_nr
    function_name
    method_name   ] = get_stack delta
  # log TRM.rainbow get_stack()
  #.........................................................................................................
  cwd   = process.cwd()
  route = route[ cwd.length + 1 ... ] if TEXT.starts_with route, cwd
  function_name ?= method_name
  function_name ?= 'NN'
  return "#{route}@#{line_nr}:#{column_nr}/#{function_name}"


#===========================================================================================================
# TIME STOPPING
#-----------------------------------------------------------------------------------------------------------
@start = ( me, idx ) ->
  now   = @now()
  me    = @_timer_from_arguments me
  #.........................................................................................................
  @_set_start_time me, now, idx
  @pending_timer_count += 1
  return me

#-----------------------------------------------------------------------------------------------------------
@stop = ( me, idx ) ->
  now = @now()
  me  = @_timer_from_arguments me
  #.........................................................................................................
  @_set_stop_time me, now, idx
  @pending_timer_count -= 1
  return me

#-----------------------------------------------------------------------------------------------------------
@_set_start_time = ( me, time, idx ) ->
  start_times = me[ 'start-times' ]
  #.........................................................................................................
  if idx?
    throw new Error "start time ##{idx} of timer #{rpr me[ 'name' ]} already set" if start_times[ idx ]?
  else
    idx = start_times.length
  #.........................................................................................................
  me[ 'mru-idx' ]     = idx
  start_times[ idx ]  = time
  return me

#-----------------------------------------------------------------------------------------------------------
@_set_stop_time = ( me, time, idx ) ->
  stop_times = me[ 'stop-times' ]
  #.........................................................................................................
  if idx?
    throw new Error "stop time ##{idx} of timer #{rpr me[ 'name' ]} already set" if stop_times[ idx ]?
  else
    idx = stop_times.length
  #.........................................................................................................
  me[ 'mru-idx' ]     = idx
  stop_times[ idx ]   = time
  # @_set_delta_time me, idx
  return me

#-----------------------------------------------------------------------------------------------------------
@_set_delta_times = ( me ) ->
  delta_times = me[ 'delta-times' ]
  #.........................................................................................................
  for time, idx in me[ 'start-times' ]
    t0  = me[ 'start-times' ][ idx ]
    t1  = me[ 'stop-times'  ][ idx ]
    #.......................................................................................................
    unless t0? and t1?
      delta_times[ idx ] = null
      continue
    #.......................................................................................................
    delta_times[ idx ] = BIGNUMBER.subtract t1, t0
  #.........................................................................................................
  return me


#===========================================================================================================
# TIME ARITHEMTICS
#-----------------------------------------------------------------------------------------------------------
@_get_total_time = ( me, times ) ->
  return BIGNUMBER.sum times
  # R = BIGNUMBER.new '0'
  # for time in times
  #   continue unless time?
  #   R = R.add time
  # return R

#-----------------------------------------------------------------------------------------------------------
@_get_sample_count = ( me, times ) ->
  R = 0
  R +=1 for time in times when time?
  return R

#-----------------------------------------------------------------------------------------------------------
@_get_average_time = ( me, times, total_time ) ->
  return BIGNUMBER.new '0' if times.length is 0
  return BIGNUMBER.divide total_time, BIGNUMBER.new times.length if total_time?
  return BIGNUMBER.average times

#-----------------------------------------------------------------------------------------------------------
@_get_min_time = ( me, times ) ->
  return BIGNUMBER.new '0' if times.length is 0
  return BIGNUMBER.min times

#-----------------------------------------------------------------------------------------------------------
@_get_max_time = ( me, times ) ->
  return BIGNUMBER.new '0' if times.length is 0
  return BIGNUMBER.max times


#===========================================================================================================
# RESULTS REPORTING
#-----------------------------------------------------------------------------------------------------------
@log_report = ->
  log @report()
  return null

#-----------------------------------------------------------------------------------------------------------
@report = ->
  R   = []
  pen = ( P... ) -> R.push TRM.pen P...
  pen()
  #.........................................................................................................
  for name, timer of @timer_by_name
    @_set_delta_times timer
    delta_times = timer[ 'delta-times' ]
    if delta_times.length is 0
      pen TRM.grey "no finished runs in #{rpr name}"
      continue
  #.........................................................................................................
  for name, timer of @timer_by_name
    delta_times     = timer[ 'delta-times' ]
    continue if delta_times.length is 0
    total_time      = timer[ 'total-time'   ] = @_get_total_time    timer, timer[ 'delta-times' ]
    average_time    = timer[ 'average-time' ] = @_get_average_time  timer, timer[ 'delta-times' ], total_time
    total_time_txt  = @_format_time timer, total_time
    number_length   = total_time_txt.length
    #.......................................................................................................
    dt_max          = @_get_max_time timer, delta_times
    dt_min          = @_get_min_time timer, delta_times
    dt_max_n        = BIGNUMBER.as_number dt_max
    #.......................................................................................................
    pen()
    pen TRM.gold name
    #.......................................................................................................
    for dt, idx in delta_times
      if dt?
        dt_n    = BIGNUMBER.as_number dt
        is_max  = BIGNUMBER.equals dt, dt_max
        is_min  = BIGNUMBER.equals dt, dt_min
        color = if is_max then 'RED' else ( if is_min then 'GREEN' else 'orange' )
        bar   = TRM[ color ]  @_bar_from_number timer, 200, dt_max_n, dt_n
        time  = TRM.orange    @_format_time     timer, dt, number_length
      else
        bar   = '🚫'
        time  = TRM.grey './.         '
      prefix = TRM.grey "run #{TEXT.flush_right ( '#' + ( idx ) ), 6}: "
      pen prefix, time, bar
    #.......................................................................................................
    average_time_n  = BIGNUMBER.as_number average_time
    bar             = TRM.steel @_bar_from_number timer, 200, dt_max_n, average_time_n
    pen ( TRM.grey 'average:    ' ), ( TRM.orange @_format_time timer, average_time, number_length ), bar
    pen ( TRM.grey 'total:      ' ),   TRM.orange total_time_txt
  #.........................................................................................................
  pen()
  return R.join ''

#-----------------------------------------------------------------------------------------------------------
#                0         1         2         3         4         5         6         7
@_bar_blocks = [ '\u2588', '\u258f', '\u258e', '\u258d', '\u258c', '\u258b', '\u258a', '\u2589', ]

#-----------------------------------------------------------------------------------------------------------
@_bar_from_number = ( me, length, max, n ) ->
  n               = Math.floor length * n / max + 0.5
  block_count     = Math.floor n / 8
  last_block_idx  = n % 8
  last_block      = if last_block_idx is 0 then '' else @_bar_blocks[ last_block_idx ]
  blocks          = ( TEXT.repeat @_bar_blocks[ 0 ], block_count ).concat last_block
  spaces          = TEXT.repeat '─', ( Math.floor length / 8 ) - blocks.length
  return blocks.concat spaces

#-----------------------------------------------------------------------------------------------------------
@_format_time = ( me, time, length ) ->
  R = add_separators BIGNUMBER.rpr time
  R = TEXT.flush_right R, length, ' ' if length?
  return R

#-----------------------------------------------------------------------------------------------------------
add_separators = ( number, width = null ) ->
  """Adapted from http://stackoverflow.com/questions/6392102/add-commas-to-javascript-output and
  http://www.mredkj.com/javascript/nfbasic.html"""
  number  = number.toString()
  x       = number.split '.'
  x1      = x[ 0 ]
  x2      = x[ 1 ]
  f       = ( n ) -> return h n, /(\d+)(\d{3})/
  g       = ( n ) -> return h n, /(\d{3})(\d+)/
  h       = ( n, re ) -> n = n.replace re, "$1" + "'" + "$2" while re.test n; return n
  R = ( f x1 ) + if x2? then '.' + g x2 else ''
  return R


#===========================================================================================================
# TIMER MANAGEMENT
#-----------------------------------------------------------------------------------------------------------
@_complain_about_pending_timers = ->
  return if @pending_timer_count is 0
  log TRM.red "There are #{@pending_timer_count} pending timers:"
  for name, timer of @timer_by_name
    log TRM.red "  #{rpr name} (#{count})" if ( count = @count_pending_runs timer ) isnt 0

#-----------------------------------------------------------------------------------------------------------
@count_pending_runs = ( me ) ->
  R = 0
  for ignored, idx in me[ 'start-times' ]
    R += 1 unless me[ 'stop-times' ][ idx ]?
  return R

#-----------------------------------------------------------------------------------------------------------
@finalize = ->
  @_complain_about_pending_timers()
  @log_report()


#===========================================================================================================
# INSTRUMENTALIZATION
#-----------------------------------------------------------------------------------------------------------
@sync_instrumentalize = ( name, method ) ->
  timer = @new name
  TIMER = @
  #.........................................................................................................
  timed_method = ( P... ) ->
    TIMER.start timer
    idx = timer[ 'mru-idx' ]
    R = method P...
    TIMER.stop timer, idx
    return R
  #.........................................................................................................
  return timed_method

#-----------------------------------------------------------------------------------------------------------
@async_instrumentalize = ( name, method ) ->
  timer = @new name
  TIMER = @
  #.........................................................................................................
  timed_method = ( P..., handler ) ->
    TIMER.start timer
    idx = timer[ 'mru-idx' ]
    do ( idx ) ->
      method P..., ( P... ) ->
        TIMER.stop timer, idx
        handler P...
  #.........................................................................................................
  return timed_method


#===========================================================================================================
# AUTOMEATED REPORTING
#-----------------------------------------------------------------------------------------------------------
process.on 'exit', @finalize.bind @


