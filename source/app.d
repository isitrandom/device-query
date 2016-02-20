import std.stdio;
import serial.device;
import std.datetime;
import std.conv;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import core.thread;

import std.range;
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

		Duration timeout = dur!("msecs")(500);

		com = new serial.device.SerialPort(port, timeout, timeout);
		com.speed = BaudRate.BR_9600;
		com.dataBits = DataBits.data8;
		com.parity = Parity.odd;

		auto data = readInfo;
		writeln("HELLO ", data.name);
		popFront();
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
		com.write("a\na\n");
		popFront;

		return this;
	}

	DeviceInfo readInfo() {
		com.write("x\n");
		auto data = read;

		foreach(line; data) {
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
			index++;
			com.write("b\n");

			auto data = read;

			if(data.length > 0) {
				return data[0].to!double;
			}

			throw new Exception("Can't read number.");
		}

		string[] read() {
			byte[512] data;
			size_t size;
			size_t readTimes;

			while(readTimes < 1000) {
				size = com.read(data);

				auto result = toStrings(data);

				if(result.length > 0) {
					//writeln("=>",index, ":", size, ":", result, "<=");
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

void main()
{
	auto rng = new RandomGenerator("/dev/cu.usbmodem1411");

	/*
	/// Select a particular pattern and display the first number
	rng.selectPattern(2).front.writeln;
	*/

	/// Select a particular pattern and display the first number
	rng.selectNextPattern.front.writeln;

	/*
	/// Get a number at a certain index
	writeln(rng[100]);
	/// you get an error if you get the number at the same index
	writeln(rng[100]);
	*/

	/*
	/// SLICING

	/// skip 100 numbers and get 100
	writeln(rng[100..200]);

	/// you get an error if you get the same slice
	writeln(rng[100..200]);
	*/

	/*
	/// Infinite loop over the numbers

	foreach(number; rng) {
		writeln(number);
	}*/

	/*
	/// How many numbers we have to read until we get a 1
	writeln(rng.countUntil(1));
	*/

	/*
	/// take 1000 numbers from the rng and put them into an array
	writeln(rng.take(1000).array);
	*/

}
