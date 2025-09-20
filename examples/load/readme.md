# Load Example

This example provides pseudo "io"-bound and "cpu"-bound endpoints for testing Falcon Limiter.

## Usage

First, start the server:

```bash
$ bundle exec ./falcon.rb
  0.0s     info: Falcon::Command::Host [oid=0x448] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | Falcon Host v0.52.3 taking flight!
               | - Configuration: ././falcon.rb
               | - To terminate: Ctrl-C or kill 8064
               | - To reload: kill -HUP 8064
 0.08s     info: Async::Container::Notify::Console [oid=0x510] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | {status: "Initializing controller..."}
 0.08s     info: Falcon::Service::Server [oid=0x520] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | Starting hello.localhost on #<Async::HTTP::Endpoint http://localhost:9292ps/ {wrapper: #<Falcon::Limiter::Wrapper:0x0000000104efe0e8 @limiter=#<Async::Limiter::Queued:0x00000001086ffcd0 @timing=Async::Limiter::Timing::None, @parent=nil, @tags=nil, @mutex=#<Thread::Mutex:0x0000000104efe188>, @queue=#<Async::PriorityQueue:0x00000001086ffd20 @items=[true], @closed=false, @parent=nil, @waiting=#<IO::Event::PriorityHeap:0x0000000104efe4a8 @contents=[]>, @sequence=0, @mutex=#<Thread::Mutex:0x0000000104efe3e0>>>>}>
 0.08s     info: Async::Service::Controller [oid=0x528] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | Controller starting...
 0.08s     info: Async::Container::Notify::Console [oid=0x510] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | {ready: true, size: 1}
 0.08s     info: Async::Service::Controller [oid=0x528] [ec=0x450] [pid=8064] [2025-09-20 16:20:08 +1200]
               | Controller started...
```

Note that the server is starting with a wrapper `Falcon::Limiter::Wrapper` which provides connection limiting, and with only a single worker (for the sake of making testing predictable).

## "CPU"-bound Work

Make several requests to the `/cpu` path:

```bash
# Start multiple requests in background
$ curl http://localhost:9292/cpu &
$ curl http://localhost:9292/cpu &
$ curl http://localhost:9292/cpu &

$ curl -v http://localhost:9292/cpu
```

You will note that these will be sequential as the connection limiter is limited to 1 connection at a time.

## "IO"-bound Work

Make several requests to the `/io` path:

```bash
# These will run concurrently (up to the long task limit)
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &

$ curl -v http://localhost:9292/io
```

You will note that these will be concurrent, as the connection limiter is released once `LongTask.current.start` is invoked.

Also note that in order to prevent persistent connections from overloading the limiter, once a connection handles an "IO"-bound request, it will be marked as non-persistent (`connection: close`). This prevents us from having several "IO"-bound requests and a "CPU"-bound request from exceeding the limit on "CPU"-bound requests, by preventing a connection that was handling an "IO"-bound request from submitting a "CPU"-bound request (or otherwise hanging while waiting on the connection limiter).

## Mixed Workload Testing

In addition, if you perform a "CPU"-bound request after starting several "IO"-bound requests, a single "CPU"-bound request will be allowed, but until it completes, no further connections will be accepted.

To see the limiter behavior with mixed workloads:

```bash
# Start several I/O requests
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &

# Then try a CPU request (should be queued until I/O requests complete)
$ curl http://localhost:9292/cpu
```

## Configuration

The example is configured with:
- **Connection limit**: 1 (only 1 connection accepted at a time).
- **Long task limit**: 4 (up to 4 concurrent I/O operations).
- **Start delay**: 0.1 seconds (delay before releasing connection token).
- **Workers**: 1 (single process for predictable behavior).

You can modify these values in `falcon.rb` by overriding the environment methods.
