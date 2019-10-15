/*******************************************************************************

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2018-2019 Mathias Lang. All rights reserved.

*******************************************************************************/

module geod24.VirtualClock;

import std.datetime.stopwatch;
import std.stdio;

import core.time;

/// By deafult we use a virtual clock.
/// The time in a virtualclock is advanced to the
/// next timer's fire time
public class VirtualClock
{
    /// Whether the clock has been paused
    private bool paused;

    /// Stopwatch used to track progress of time
    private StopWatch sw;

    /// The initial start time of the clock
    private const MonoTime start_time;


    /// Start the clock
    public this () nothrow @nogc @safe
    {
        this.start_time = MonoTime.currTime();
        this.sw = StopWatch(AutoStart.yes);
    }

    /// Return the current virtual time
    public MonoTime currTime () nothrow
    {
        return this.start_time + this.sw.peek();
    }

    /// Pause the clock. When continuing, the
    public void pause ()
    {
        this.paused = true;
        this.sw.stop();
    }

    /// Continue the clock from where it paused
    public void resume ()
    {
        if (!this.paused)
            return;

        this.sw.start();
        this.paused = false;
    }

    /// Note: the offset may be negative
    public void addTimeOffset (Duration duration)
    {
        this.sw.setTimeElapsed(this.sw.peek() + duration);
    }
}
