# process-stats.sh

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Collect and visualise resource usage statistics for a single Linux process.

This script is a wrapper around `pidstat` (from the [sysstat](http://sebastien.godard.pagesperso-orange.fr/index.html) package), [NetHogs](https://github.com/raboof/nethogs) (which usually requires root access to capture network packages with libpcap) and [RRDtool](https://oss.oetiker.ch/rrdtool/).

Other requirements: Bash, gawk, getopt from "util-linux".

![example.svg](https://gist.githubusercontent.com/stefantalpalaru/001426d63b754e7badeeb6767adca5e5/raw/f23d083555dd71c3bfb5fd21cd4f0993df473a95/example.svg)

## How to use

```text
Usage: process-stats.sh --pid <process ID> [OTHER OPTIONS]
E.g.: process-stats.sh --pid 12345 --out bla # produces bla.rrd, bla.sh and bla.svg

  -p, --pid		the process ID of the target program (mandatory
			argument)
  -h, --help		this help message
  -v, --verbose		show raw data on stdout
  -o, --output		base filename for the generated .rrd, .sh and .svg files
			(defaults to "out")
  -r, --rows		maximum number of rows in the RRD file (defaults to
			100000 and, at one datapoint per second, it's also the
			maximum duration of recorded and visualised data)
  -g, --graph-generation-interval
			interval in seconds at which the SVG graph is being
			regenerated during data collection (default: 60, set it
			to 0 to disable)
      --height		graph height (in pixels, default: 800)
      --min-width	minimum graph width (default: 1000)
```

### Real-life example

(Taken from here: https://github.com/status-im/nimbus/issues/262)

```bash
# in one terminal:
rm -rf ~/.cache/nimbus/db; time ./build/nimbus --prune:archive --port:30304 &>output3.log
# in another terminal, logged in as root, knowing that there is only one "nimbus" process running,
# collecting a maximum of 100000 rows (the default), once per second, showing the raw data on stdout:
./process-stats.sh -v -p $(pidof nimbus) -o nimbus3
```

The data collection ends when the target process exits or when Ctrl+C is
pressed. After this, you'll find three new files in your current directory:

- "nimbus3.rrd" - collected data
- "nimbus3.sh" - graphing script that can you edit and run again to process "nimbus3.rrd" and regenerate "nimbus3.svg"
- "nimbus3.svg" - resulting graph, with a minimum width of 1000 and a maximum width equal to the number of collected rows (that is to say, the duration in seconds)

As you can see, in this case the duration was almost five hours and a half, making it hard to see the big picture:

![nimbus3-long.svg](https://gist.githubusercontent.com/stefantalpalaru/8a676e9ba726b4d5b73107fc9ba23f58/raw/a89f2b9f022df2f7ed6fd31667d421a96a98349a/nimbus3-long.svg?sanitize=true)

I modified "nimbus3.sh" to divide the graph width by five, in order to show five seconds per pixel and ran it again:

![nimbus3-short.svg](https://gist.githubusercontent.com/stefantalpalaru/04e3bdf9630cf19b65fb2878daa107b5/raw/a2291a0e7705e780f7cd0d21b85786a13b8fc3dc/nimbus3-short.svg?sanitize=true)

Now the memory leak is clear, while maintaining enough info about the serial nature of the program and its bottlenecks.

Bonus feature: the SVG graph is regenerated every minute, during data
collection, so you don't have to wait until the end to see what's what.
Some image viewers (like [Geeqie](http://geeqie.org/)) refresh the image
automatically when the file changes.

## TODO

- show voluntary context switches

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.

## Homepage

https://github.com/status-im/process-stats

