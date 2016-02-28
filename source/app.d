import isitrandom.generator;

import std.stdio;

void main()
{
	auto rng = new RandomGenerator("/dev/cu.usbmodem1411");

	/*
	/// Select a particular pattern and display the first number
	rng.selectPattern(2).front.writeln;
	*/

	/*
	/// Select the next pattern and display the first number
	rng.selectNextPattern.front.writeln;
	*/

	/*
	/// Get a number at a certain index
	rng[100].writeln;
	/// you get an error if you get the number at the same index
	rng[100].writeln;
	*/

	/*
	/// SLICING

	/// skip 100 numbers and get 100
	rng[100..200].writeln;

	/// you get an error if you get the same slice
	rng[100..200].writeln;
	*/

	/*
	/// Infinite loop over the numbers

	foreach(number; rng) {
		writeln(number);
	}*/

	/*
	/// How many numbers we have to read until we get a 1
	rng.countUntil(1).writeln;
	*/

	/*
	/// take 1000 numbers from the rng and put them into an array
	rng.take(1000).array.writeln;
	*/

	// get 1000 numbers without showing them on the display (it's faster)
	//rng.setDisplay(false).take(1000).array.writeln;
}
