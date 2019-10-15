/*******************************************************************************

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2018-2019 Mathias Lang. All rights reserved.

*******************************************************************************/

module geod24.VirtualClock;

import std.algorithm;
import std.range;
import std.stdio;

import core.sync.mutex;
import core.time;

/// Contains the "time" and the sequence
/// The sequence is used in case there are multiple events scheduled for the
/// same time, in that case we want to preserve the ordering of the events.
struct VirtualEventT (Time)
{
    // cannot be 'const' due to inability to sort()
    public /* const */ Time time;
    private size_t seq;

    public this (Time time, size_t seq)
    {
        this.time = time;
        this.seq = seq;
    }

    public int opCmp (ref const(typeof(this)) rhs) const
    {
        if (time > rhs.time)
            return 1;
        else if (time < rhs.time)
            return -1;

        if (seq > rhs.seq)
            return 1;
        else if (seq < rhs.seq)
            return -1;

        return 0;
    }
}

///
unittest
{
    alias VE = VirtualEventT!int;
    auto events = [VE(20, 1), VE(20, 0), VE(10, 1), VE(10, 0)];
    sort(events);
    assert(events == [VE(10, 0), VE(10, 1), VE(20, 0), VE(20, 1)]);
}

/// Virtual event which uses a MonoTime
public alias VirtualEvent = VirtualEventT!MonoTime;

/// By deafult we use a virtual clock.
/// The time in a virtualclock is advanced to the
/// next timer's fire time
public class VirtualClock
{
    /// Priority queue of all events (global!)
    __gshared VirtualEvent[] prio_queue;

    /// Time when the main thread started
    __gshared MonoTime start_time;

    /// monotonic clock (not wall clock), it always moves forward, never back.
    __gshared MonoTime cur_time;

    /// Must guard access to the virtal clock, as it is shared by all threads
    __gshared Mutex mutex;

    shared static this ()
    {
        // initialized once
        start_time = cur_time = MonoTime.currTime;

        mutex = new Mutex();
    }

    /// Return the current virtual time
    public static MonoTime currTime () nothrow
    {
        // todo: synchronized() is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            return cur_time;
        }
    }

    /// Add an event, using the current virtual time
    public static VirtualEvent addEvent () nothrow
    {
        // todo: synchronized() is not nothrow
        // todo: body is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            auto time = VirtualClock.currTime();
            auto event = VirtualEvent(time, getNextSequence(time));

            this.prio_queue ~= event;

            // todo: replace with priority queue
            // note: BinaryHeap in Phobos doesn't expose .back(), we need it.
            sort(this.prio_queue);

            //writefln("-- addEvent(): Prio Queue: %s",
            //    this.prio_queue.map!(item => item.time - start_time));

            return event;
        }
    }

    /// If a fiber will wake up at a later point, this is considered to be
    /// an event of sorts
    public static VirtualEvent addWaitEvent (Duration period) nothrow
    {
        // todo: synchronized() is not nothrow
        // todo: body is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            auto wake_time = VirtualClock.currTime + period;
            auto event = VirtualEvent(wake_time, getNextSequence(wake_time));

            this.prio_queue ~= event;

            // todo: replace with priority queue
            // note: BinaryHeap in Phobos doesn't expose .back(), we need it.
            sort(this.prio_queue);

            //writefln("-- addWaitEvent(): Prio Queue: %s",
            //    this.prio_queue.map!(item => item.time - start_time));

            if (this.prio_queue.length == 1)
            {
                // if this is the only event, then time should be advanced
                // todo: this doesn't work!
                advanceTime();
            }

            return event;
        }
    }

    /// Remove an event. It should be called once an event is ready to fire,
    /// before the event callback is actually invoked. A simple way to do this
    /// is to wrap the delegate call in a wrapper delegate which first removes
    /// the previously added event, and then calls the wrapped delegate.
    public static void removeEvent (VirtualEvent event) nothrow
    {
        // todo: synchronized() is not nothrow
        // todo: body is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            // todo: optimize
            auto idx = this.prio_queue.countUntil(event);
            if (idx < 0)  // sanity check
                assert(0, "Event was already removed??");

            dropIndex(this.prio_queue, idx);
        }
    }

    public static size_t getNextSequence (MonoTime time)
    {
        // todo: synchronized() is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            // no events => seq 0
            if (this.prio_queue.length == 0)
                return 0;

            // last item in queue has same time => get next incremented sequence
            auto back = this.prio_queue.back;
            if (back.time == time)
                return back.seq + 1;

            // want to add a newer time => seq 0 is ok
            return 0;
        }
    }

    public static void advanceTime () nothrow
    {
        // todo: synchronized() is not nothrow
        scope (failure) assert(0);

        synchronized (mutex)
        {
            // cannot advance time, no virtual events are waiting,
            // no timers are waiting either
            if (this.prio_queue.length == 0)
                return;

            if (this.cur_time >= this.prio_queue.front.time)
                return;

            auto advanced_by = this.prio_queue.front.time - cur_time;
            auto prev_time = cur_time - start_time;
            cur_time = this.prio_queue.front.time;
            writefln("Advanced time by %s from +%s to +%s (%s)",
                advanced_by, prev_time, cur_time - start_time,
                MonoTime.currTime - start_time);
        }
    }
}

/**
    Drop element at index from array and update array length.
    Note: This is extremely unsafe, it assumes there are no
    other pointers to the internal slice memory.
*/
private static void dropIndex (T)(ref T[] arr, size_t index) @trusted
{
    import core.stdc.string;
    assert(index < arr.length);
    immutable newLen = arr.length - 1;

    if (index != newLen)
        memmove(&(arr[index]), &(arr[index + 1]), T.sizeof * (newLen - index));

    arr.length = newLen;
}

///
unittest
{
    int[] arr = [1, 2, 3];
    arr.dropIndex(1);
    assert(arr == [1, 3]);
}
