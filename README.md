# process-stats.sh

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Collect and visualise resource usage for a single Linux process.

This script is a wrapper around `pidstat` (from the [sysstat][http://sebastien.godard.pagesperso-orange.fr/index.html] package), [NetHogs][https://github.com/raboof/nethogs] (which usually requires root access to capture network packages with libpcap) and [RRDtool][https://oss.oetiker.ch/rrdtool/].

Other requirements: Bash, gawk, getopt from "util-linux".

## How to use

```bash
process-stats.sh --pid <process ID> [--out base_filename] [--rows <maximum number of rows in the db (default: 100000)>] [--verbose]
```

For example
```bash
process-stats.sh --pid 12345 --out bla # produces bla.rrd, bla.sh and bla.svg
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

Now the memory leak is clear, while maintaining enough info about the serial nature of the program.

## TODO

- improve the colour scheme
- show voluntary context switches

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.

