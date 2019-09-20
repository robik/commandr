# commandr

Command Line arguments parser for modern age.


## About

`commandr` is a library that makes handling command-line arguments as effortless as possible, while maintaining 
a clean and intuitive API. Rather than making you focus on parsing the arguments yourself, you describe your program
arguments by creating a `Program` model. Arguments parsing, help output and auto-completion is provided by `commandr`.


## Example

```D
import std.stdio;
import commandr;

void main(string[] args) {
    Program p;
    ProgramArgs a;

    try {
	    p = Program("test", "1.0")
            .summary("Command line parser")
            .author("John Doe <me@foo.bar.com>")
            .add(Flag("v", null, "turns on more verbose output")
                .name("verbose")
                .repeating)
            .add(Option(null, "test", "some teeeest"))
            .add(Argument("path", "Path to file to edit")
                .required)
            ;

        a = p.parse(args);
        writeln("verbosity level", a.occurencesOf("verbose"));
        writeln("arg: ", a.arg("path"));
    } catch(InvalidProgramException e) {
        writeln("Whoops, program declaration is wrong: ", e.msg);
    } catch(InvalidArgumentsException e) {
        writeln("Error: ", e.msg);
        p.printUsage();
    }
}
```

## Installation

Add this entry to your `dub.json` file:

```json
  "dependencies": {
    ...
    "commandr": "~>1.0"
    ...
  }
```


## Features

 - **Flags** (boolean values)
   - Short and long forms are supported (`-v`, `--verbose`)
   - Supports stacking of flags (`-vvvv` is same as `-v -v -v`)

 - **Options** (taking a string value)
   - Short and long forms are supported (`-c test`, `--config test`)
   - Equals sign accepted (`-c=1`, `--config=test`)
   - Repeated options are supported (`-c 1 -c 2`)
   - Default values can be specified.
   - Options be marked as required.

 - **Arguments** (positional)
   - Can be marked as required
   - Default values can be specified.
   - Repeated options are supported (only last argument)

 - **Automated help generation**
   - Can be configured/partially overriden to suit your needs, such as forced disabling of ANSI codes.
   - Provided usage, help and version information.
   - Completly detached from core `Program`, giving you complete freedom in writing your own.

 - **Consistency checking**
   - When you build your program model, `commandr` checks its consistency.
   - Detects name duplications as well as short/long options.
   - Detects required parameters with default value.

 - **Triggers**
   - You can specify multiple triggers on a flag/option/argument that gets called when a parameter is found.
   - Useful when you need to cover that _edge case_ scenario.


## Limitations

TODO: commands
TODO: Automatic BASH completion script
TODO: Combined options `-qLop`
TODO: validations
TODO: enum/value sets
TODO: conflicts
TODO: With negative value (`no-` prefix)
TODO: hinting (for completion)
TODO: suggestions
TODO: help output grouping
TODO: better help configuration and output