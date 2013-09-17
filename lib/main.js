(function() {
  var BIGNUMBER, TEXT, TRM, TYPES, add_separators, echo, get_stack, log, njs_hrtime, rpr;

  njs_hrtime = process.hrtime;

  get_stack = require('coffeenode-stacktrace/lib/get-stack');

  TRM = require('coffeenode-trm');

  TEXT = require('coffeenode-text');

  TYPES = require('coffeenode-types');

  log = TRM.log.bind(TRM);

  rpr = TRM.rpr.bind(TRM);

  echo = TRM.echo.bind(TRM);

  BIGNUMBER = require('coffeenode-bignumber');

  this.timer_by_name = {};

  this.pending_timer_count = 0;

  this._hrtime_resolution = 1e9;

  /* nothing here yet*/


  this.now = function(me) {
    var R;
    R = njs_hrtime();
    return BIGNUMBER["new"]("" + R[0] + "." + (TEXT.flush_right(R[1], 9, '0')));
  };

  this.new_timer = function(name) {
    var R;
    if (name == null) {
      if (name == null) {
        name = this._name_from_caller_location(2);
      }
    }
    if (this.timer_by_name[name] != null) {
      bye("timer named " + (rpr(name)) + " already in use");
    }
    R = {
      '~isa': 'TIMER/timer',
      'name': name,
      'start-times': [],
      'stop-times': [],
      'delta-times': [],
      'total-time': null,
      'average-time': null,
      'mru-idx': null
    };
    this.timer_by_name[name] = R;
    return R;
  };

  this._fetch_timer = function(name) {
    var _ref;
    return (_ref = this.timer_by_name[name]) != null ? _ref : this.new_timer(name);
  };

  this._timer_from_arguments = function(x) {
    var types;
    if (x != null) {
      if (TYPES.isa_text(x)) {
        return this._fetch_timer(x);
      }
      if ((types = TYPES.type_of(x)) !== 'TIMER/timer') {
        throw new Error("expected a text or a timer, got a " + type);
      }
      return x;
    }
    return this._fetch_timer(this._name_from_caller_location(3));
  };

  this._name_from_caller_location = function(delta) {
    var column_nr, cwd, function_name, line_nr, method_name, route, _ref;
    _ref = get_stack(delta), route = _ref[0], line_nr = _ref[1], column_nr = _ref[2], function_name = _ref[3], method_name = _ref[4];
    cwd = process.cwd();
    if (TEXT.starts_with(route, cwd)) {
      route = route.slice(cwd.length + 1);
    }
    if (function_name == null) {
      function_name = method_name;
    }
    if (function_name == null) {
      function_name = 'NN';
    }
    return "" + route + "@" + line_nr + ":" + column_nr + "/" + function_name;
  };

  this.start = function(me, idx) {
    var now;
    now = this.now();
    me = this._timer_from_arguments(me);
    this._set_start_time(me, now, idx);
    this.pending_timer_count += 1;
    return me;
  };

  this.stop = function(me, idx) {
    var now;
    now = this.now();
    me = this._timer_from_arguments(me);
    this._set_stop_time(me, now, idx);
    this.pending_timer_count -= 1;
    return me;
  };

  this._set_start_time = function(me, time, idx) {
    var start_times;
    start_times = me['start-times'];
    if (idx != null) {
      if (start_times[idx] != null) {
        throw new Error("start time #" + idx + " of timer " + (rpr(me['name'])) + " already set");
      }
    } else {
      idx = start_times.length;
    }
    me['mru-idx'] = idx;
    start_times[idx] = time;
    return me;
  };

  this._set_stop_time = function(me, time, idx) {
    var stop_times;
    stop_times = me['stop-times'];
    if (idx != null) {
      if (stop_times[idx] != null) {
        throw new Error("stop time #" + idx + " of timer " + (rpr(me['name'])) + " already set");
      }
    } else {
      idx = stop_times.length;
    }
    me['mru-idx'] = idx;
    stop_times[idx] = time;
    return me;
  };

  this._set_delta_times = function(me) {
    var delta_times, idx, t0, t1, time, _i, _len, _ref;
    delta_times = me['delta-times'];
    _ref = me['start-times'];
    for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
      time = _ref[idx];
      t0 = me['start-times'][idx];
      t1 = me['stop-times'][idx];
      if (!((t0 != null) && (t1 != null))) {
        delta_times[idx] = null;
        continue;
      }
      delta_times[idx] = BIGNUMBER.subtract(t1, t0);
    }
    return me;
  };

  this._get_total_time = function(me, times) {
    return BIGNUMBER.sum(times);
  };

  this._get_sample_count = function(me, times) {
    var R, time, _i, _len;
    R = 0;
    for (_i = 0, _len = times.length; _i < _len; _i++) {
      time = times[_i];
      if (time != null) {
        R += 1;
      }
    }
    return R;
  };

  this._get_average_time = function(me, times, total_time) {
    if (times.length === 0) {
      return BIGNUMBER["new"]('0');
    }
    if (total_time != null) {
      return BIGNUMBER.divide(total_time, BIGNUMBER["new"](times.length));
    }
    return BIGNUMBER.average(times);
  };

  this._get_min_time = function(me, times) {
    if (times.length === 0) {
      return BIGNUMBER["new"]('0');
    }
    return BIGNUMBER.min(times);
  };

  this._get_max_time = function(me, times) {
    if (times.length === 0) {
      return BIGNUMBER["new"]('0');
    }
    return BIGNUMBER.max(times);
  };

  this.log_report = function() {
    var average_time, average_time_n, bar, color, delta_times, dt, dt_max, dt_max_n, dt_min, dt_n, idx, is_max, is_min, name, number_length, prefix, time, timer, total_time, total_time_txt, _i, _len, _ref, _ref1;
    log();
    _ref = this.timer_by_name;
    for (name in _ref) {
      timer = _ref[name];
      this._set_delta_times(timer);
      delta_times = timer['delta-times'];
      if (delta_times.length === 0) {
        log(TRM.grey("no finished runs in " + (rpr(name))));
        continue;
      }
    }
    _ref1 = this.timer_by_name;
    for (name in _ref1) {
      timer = _ref1[name];
      delta_times = timer['delta-times'];
      if (delta_times.length === 0) {
        continue;
      }
      total_time = timer['total-time'] = this._get_total_time(timer, timer['delta-times']);
      average_time = timer['average-time'] = this._get_average_time(timer, timer['delta-times'], total_time);
      total_time_txt = this._format_time(timer, total_time);
      number_length = total_time_txt.length;
      dt_max = this._get_max_time(timer, delta_times);
      dt_min = this._get_min_time(timer, delta_times);
      dt_max_n = BIGNUMBER.as_number(dt_max);
      log(BIGNUMBER.rpr(dt_max));
      log(BIGNUMBER.rpr(dt_min));
      log();
      log(TRM.gold(name));
      for (idx = _i = 0, _len = delta_times.length; _i < _len; idx = ++_i) {
        dt = delta_times[idx];
        if (dt != null) {
          dt_n = BIGNUMBER.as_number(dt);
          is_max = BIGNUMBER.equals(dt, dt_max);
          is_min = BIGNUMBER.equals(dt, dt_min);
          color = is_max ? 'RED' : (is_min ? 'GREEN' : 'orange');
          bar = TRM[color](this._bar_from_number(timer, 200, dt_max_n, dt_n));
          time = TRM.orange(this._format_time(timer, dt, number_length));
        } else {
          bar = '🚫';
          time = TRM.grey('./.         ');
        }
        prefix = TRM.grey("run " + (TEXT.flush_right('#' + idx, 6)) + ": ");
        log(prefix, time, bar);
      }
      average_time_n = BIGNUMBER.as_number(average_time);
      bar = TRM.steel(this._bar_from_number(timer, 200, dt_max_n, average_time_n));
      log(TRM.grey('average:    '), TRM.orange(this._format_time(timer, average_time, number_length)), bar);
      log(TRM.grey('total:      '), TRM.orange(total_time_txt));
    }
    log();
    return null;
  };

  this._bar_blocks = ['\u2588', '\u258f', '\u258e', '\u258d', '\u258c', '\u258b', '\u258a', '\u2589'];

  this._bar_from_number = function(me, length, max, n) {
    var block_count, blocks, last_block, last_block_idx, spaces;
    n = Math.floor(length * n / max + 0.5);
    block_count = Math.floor(n / 8);
    last_block_idx = n % 8;
    last_block = last_block_idx === 0 ? '' : this._bar_blocks[last_block_idx];
    blocks = (TEXT.repeat(this._bar_blocks[0], block_count)).concat(last_block);
    spaces = TEXT.repeat('─', (Math.floor(length / 8)) - blocks.length);
    return blocks.concat(spaces);
  };

  this._format_time = function(me, time, length) {
    var R;
    R = add_separators(BIGNUMBER.rpr(time));
    if (length != null) {
      R = TEXT.flush_right(R, length, ' ');
    }
    return R;
  };

  add_separators = function(number, width) {
    var R, f, g, h, x, x1, x2;
    if (width == null) {
      width = null;
    }
    "Adapted from http://stackoverflow.com/questions/6392102/add-commas-to-javascript-output and\nhttp://www.mredkj.com/javascript/nfbasic.html";
    number = number.toString();
    x = number.split('.');
    x1 = x[0];
    x2 = x[1];
    f = function(n) {
      return h(n, /(\d+)(\d{3})/);
    };
    g = function(n) {
      return h(n, /(\d{3})(\d+)/);
    };
    h = function(n, re) {
      while (re.test(n)) {
        n = n.replace(re, "$1" + "'" + "$2");
      }
      return n;
    };
    R = (f(x1)) + (x2 != null ? '.' + g(x2) : '');
    return R;
  };

  this._complain_about_pending_timers = function() {
    var count, name, timer, _ref, _results;
    if (this.pending_timer_count === 0) {
      return;
    }
    log(TRM.red("There are " + this.pending_timer_count + " pending timers:"));
    _ref = this.timer_by_name;
    _results = [];
    for (name in _ref) {
      timer = _ref[name];
      if ((count = this.count_pending_runs(timer)) !== 0) {
        _results.push(log(TRM.red("  " + (rpr(name)) + " (" + count + ")")));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  this.count_pending_runs = function(me) {
    var R, idx, ignored, _i, _len, _ref;
    R = 0;
    _ref = me['start-times'];
    for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
      ignored = _ref[idx];
      if (me['stop-times'][idx] == null) {
        R += 1;
      }
    }
    return R;
  };

  this.finalize = function() {
    this._complain_about_pending_timers();
    return this.log_report();
  };

  process.on('exit', this.finalize.bind(this));

}).call(this);
/****generated by https://github.com/loveencounterflow/larq****/