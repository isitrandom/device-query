module isitrandom.generator;

import std.stdio;
import std.string;
import serial.device;
import std.datetime;

import core.thread;

public {
  import std.conv;
  import std.algorithm.iteration;
  import std.algorithm.searching;
  import std.array;
  import std.range;
}

import std.range.interfaces;


struct DeviceInfo {
	string name;
	string description;
	int pattern;
}

class RandomGenerator: InputRange!double {

	private {
		ulong index;
		serial.device.SerialPort com;
		double lastNumber;
		bool isError;
	}

	this() {
    writeln("available ports: ", SerialPort.ports);

		foreach(port; SerialPort.ports) {
			try {
				connect(port);
			} catch(Exception e) {
				writeln(e.msg);
			}
		}
	}

	this(string port) {
		try {
			connect(port);
		} catch(Exception e) {
			writeln(e.msg);
		}
	}

	void connect(string port) {
		writeln("\nConnecting on port: \"", port, "\"");

		Duration timeout = dur!("msecs")(10);

		com = new serial.device.SerialPort(port, timeout, timeout);
		com.speed = BaudRate.BR_9600;
		com.dataBits = DataBits.data8;
		com.parity = Parity.odd;

		auto data = readInfo;
		writeln("HELLO ", data.name);
		popFront;
	}

	@property {
		double front() {
			return lastNumber;
		}

		bool empty() {
			return com.closed() || isError;
		}
	}

	double moveFront() {
		popFront();
		return front;
	}

	void popFront() {
		try {
			lastNumber = readNumber();
		} catch(Exception e) {
				isError = true;
				writeln(e.msg);
			}
		}

	int opApply(int delegate(double) dg) {
		int result = 0;

		while(!isError) {
			result = dg(front);
			popFront();
			if (result) break;
		}

		return result;
	}

	int opApply(int delegate(size_t, double) dg) {
		int result = 0;

		while(!isError) {
			result = dg(index, front);
			popFront();
			if (result) break;
		}

		return result;
	}

	RandomGenerator selectPattern(int pattern) {
		com.write("p:" ~ pattern.to!string ~ "\n");
		popFront;

		return this;
	}

	RandomGenerator selectNextPattern() {
		com.write("aa");
		popFront;

		return this;
	}

  RandomGenerator setDisplay(bool visible) {
    com.write(visible ? "d" : "c");

    return this;
  }

  double[] take(int count) {
    double[] list = [ front ];

    auto msg = "t:" ~ count.to!string ~ "\n";
    com.write(msg);

    try {
      while(list.length < count) {
        list ~= waitNumbers;
      }
    } catch(Exception e) {
      e.msg.writeln;
    }

    popFront;

    return list;
  }

	DeviceInfo readInfo() {
		com.write("x");

		string[] data;

    while(!data.canFind!(a => a.startsWith("info:"))) {
      data = read;
    }

		foreach(line; data.filter!(a => a.startsWith("info:"))) {
			auto info = line.split(":");

			if(info[0] == "info") {
				return DeviceInfo(info[1], info[2], info[3].to!int);
			}
		}

		throw new Exception("Can't get device info");
	}

	double[] opSlice(size_t begin, size_t end) {
		if(index > begin) {
			throw new Exception("You already got " ~ index.to!string ~ " numbers. I can't go back.");
		}

		while(index < begin) {
			readNumber();
		}

		double[] list;

		while(index < end) {
			list ~= readNumber;
		}

		return list;
	}

	double opIndex(size_t begin) {
		if(index > begin) {
			throw new Exception("You already got " ~ index.to!string ~ " numbers. I can't go back.");
		}

		while(index < begin) {
			readNumber();
		}

		return readNumber();
	}

	private {
		double readNumber() {
			com.write("b\n");
			return waitNumbers[0];
		}

    double[] waitNumbers() {
      auto data = read;
      index += data.length;
			return data.filter!(a => a.isNumeric(true)).map!(a => a.to!double).array;
		}

		string[] read() {
			byte[512] data;
			size_t readTimes;

			while(readTimes < 1000) {
        try {
          com.read(data);
        } catch(Exception e) {

        }
				auto result = toStrings(data);

				if(result.length > 0) {
					return result;
				}

				Thread.sleep( dur!("msecs")( 1 ) );
				readTimes++;
			}

			return [];
		}

		string[] toStrings(T)(T data) {
			auto end = (cast(byte[])data).countUntil(0);

			if(end == -1) {
				end = data.length;
			}

			auto received = cast(char[]) data[0..end];

			return received.to!string.idup
								.filter!`a != '\r'`.to!string
								.splitter("\n")
								.filter!`a != "0" && a != "00" && a != ""`
								.array;
		}
	}
}
