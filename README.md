<!-- LOGO -->
<p align="center">
  <a href="https://github.com/robik/commandr">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h2 align="center">commandr</h2>

  <p align="center">
    A modern, powerful commmand line argument parser. 
    <br>
    Batteries included.
    <br />
    <br />
    <a href="https://robik.github.io/commandr/"><strong>📗 Explore the docs »</strong></a>
    <br />
    <a href="https://github.com/robik/commandr/issues">❗️ Report a bug</a>
    ·
    <a href="https://github.com/robik/commandr/issues">💡 Request feature</a>    
    <br />  
    <br />
    <img src="https://img.shields.io/travis/robik/commandr?style=flat-square">
    <img src="https://img.shields.io/dub/v/commandr?style=flat-square">
    <img src="https://img.shields.io/github/issues/robik/commandr.svg?style=flat-square">
    <img src="https://img.shields.io/github/license/robik/commandr.svg?style=flat-square">
    <img src="https://img.shields.io/badge/language-D-red?style=flat-square">
    <br />
  </p>
</p>

- - -

**commandr** handles all kinds of command-line arguments with a nice and clean interface.<br/>
Comes with help generation, shell auto-complete scripts and validation. 


## Table of Contents

 - [Preview](#preview)
 - [Installation](#installation)
 - [FAQ](#faq)
 - [Features](#features)
 - [Getting Started](#getting-started)
   - [Usage](#usage)
   - [Subcommands](#subcommands)
   - [Printing help](#printing-help)
   - [Configuration](#configuration)
 - [Cheat-Sheet](#cheat-sheet)
   - [Defining Entries](#defining-entries)
   - [Reading Values](#reading-values)
   - [Property Matrix](#property-matrix)
 - [Roadmap](#roadmap)
 - [License](#license)


## Preview

<p align="center">
<img src="./images/help.png">
</p>

## Installation

Add this entry to your `dub.json` file:

```json
  "dependencies": {
    ...
    "commandr": "~>0.1"
    ...
  }
```

## FAQ

 - **Does it use templates/compile-time magic?**
   
   No, at least currently not. Right now everything is done at runtime, so there's not much overhead on compilation time resources.
   In the future I'll probably look into generation of compile-time struct.

   The reason is that I want it to be rather simple and easy to learn, and having a lot of generated code hurts e.g. generated documentation
   and some minor things such as IDE auto-complete (even right now mixin-s cause some problems).

 - **Are the results typesafe? / Does it use UDA?**

   No, parsed arguments are returned in a `ProgramArgs` class instance that allow to fetch parsed data,

   However it should be possible to generate program definition from struct/class with UDA and then 
   fill the parsed data into struct instance, but it is currently out of scope of this project (at least for now).


## Features

 - **Flags** (boolean values)
   - Short and long forms are supported (`-v`, `--verbose`)
   - Supports stacking of flags (`-vvv` is same as `-v -v -v`)

 - **Options** (taking a string value)
   - Short and long forms are supported (`-c test`, `--config test`)
   - Equals sign accepted (`-c=1`, `--config=test`)
   - Repeated options are supported (`-c 1 -c 2`)
   - Default values can be specified.
   - Options be marked as required.

 - **Arguments** (positional)
   - Required by default, can be marked as optional
   - Default values can be specified.
   - Repeated options are supported (only last argument)

 - **Commands** (git-style)
   - Infinitely recursive subcommands (you can go as deep as needed)
   - Contains own set of flags/options and arguments
   - Dedicated help output
   - Comfortable command handling with `ProgramArgs.on()`

 - **Provided help output**
   - Generated help output for your program and sub-commands
   - Can be configured to suit your needs, such as disabling colored output.
   - Provided usage, help and version information.
   - Completly detached from core `Program`, giving you complete freedom in writing your own help output.
   - You can categorize commands for better help output

 - **Consistency checking**
   - When you build your program model, `commandr` checks its consistency.
   - Detects name duplications as well as short/long options.
   - Detects required parameters with default value.

 - **BASH auto-complete script**
   - You can generate completion script with single function call
   - Completion script works on flags, options and sub-commands (at any depth)
   - Acknowledges difference between flags and options

 - **Validators**
   - Passed values can be checked for correctness
   - Simple process of creating custom validating logic
   - Provided validators for common cases: `EnumValidator`, `FileSystemValidator` and `DelegateValidator`

 - **Suggestions**
   - Suggestion with correct flag, option or sub-command name is provided when user passes invalid value
   - Also supported for `EnumValidator` (`acceptsValues`)


## Getting Started

### Usage

Simple example showing how to create a basic program and parse arguments:

```D
import std.stdio;
import commandr;

void main(string[] args) {
    auto a = new Program("test", "1.0")
          .summary("Command line parser")
          .author("John Doe <me@foo.bar.com>")
          .add(new Flag("v", null, "turns on more verbose output")
              .name("verbose")
              .repeating)
          .add(new Option(null, "test", "some teeeest"))
          .add(new Argument("path", "Path to file to edit"))
          .parse(args);

      writeln("verbosity level", a.occurencesOf("verbose"));
      writeln("arg: ", a.arg("path"));
}
```

### Subcommands

You can create subcommands in your program or command using `.add`. You can nest commands.

Adding subcommands adds a virtual required argument at the end to your program. This makes you unable to declare repeating or optional arguments (because you cannot have required argument past these).

Default command can be set with `.defaultCommand(name)` call after defining all commands.

After parsing, every subcommand gets its own `ProgramArgs` instance, forming a hierarchy. Nested args inherit arguments from parent, so that options defined higher
in hierarchy are copied.
ProgramArgs defines a helper method `on`, that allows to dispatch method on specified command.

```D
auto a = new Program("test", "1.0")
      .add(new Flag("v", null, "turns on more verbose output")
          .name("verbose")
          .repeating)
      .add(new Command("greet")
          .add(new Argument("name", "name of person to greet")))
      .add(new Command("farewell")
          .add(new Argument("name", "name of person to say farewell")))
      .parse(args);

a.on("greet", (args) {
  // args.flag("verbose") works
  writefln("Hello %s!", args.arg("name"));
}).on("farewell", (args) {
  writefln("Bye %s!", args.arg("name"));
});

```

### Printing help


### Configuration


## Cheat-Sheet

### Defining entries

Overview of available entries that can be added to program or command with `.add` method:

What         | Type     | Example     | Definition                            
-------------|----------|-------------|---------------------------------------
**Flag**     | bool     | `--verbose` | `new Flag(abbrev?, full?, summary?)`  
**Option**   | string[] | `--db=test` | `new Option(abbrev?, full?, summary?)`
**Argument** | string[] | `123`       | `new Argument(name, summary?)`        


### Reading values

Shows how to access values after parsing args.

Examples assume `args` variable contains result of `parse()` or `parseArgs()` function calls (an instance of `ProgramArgs`)

```D
ProgramArgs args = program.parse(args);
```

What         | Type     | Fetch
-------------|----------|--------------------
**Flag**     | bool     | `args.flag(name)`
**Flag**     | int      | `args.occurencesOf(name)`
**Option**   | string   | `args.option(name)`
**Option**   | string[] | `args.options(name)`
**Argument** | string   | `args.arg(name)`
**Argument** | string[] | `args.args(name)`


### Property Matrix

<!-- ✅ ❌ -->

Table below shows which fields exist and which don't (or should not be used).

Column `name` contains name of the method to set the value. All methods return
`this` to allow chaining.

Name                 | Program | Command | Flag | Option | Argument
---------------------|---------|---------|------|--------|---------
`.name`              | ✅      | ✅      | ✅   | ✅     | ✅
`.version_`          | ✅      | ✅      | ❌   | ️❌     | ❌
`.summary`           | ✅️      | ️✅      | ❌   | ️❌     | ❌
`.description`       | ❌      | ️❌      | ✅   | ️✅     | ✅
`.abbrev`            | ❌      | ❌      | ✅   | ✅     | ❌
`.full`              | ❌      | ❌      | ✅️   | ️✅     | ❌
`.tag`               | ❌      | ❌      | ❌   | ️✅     | ✅️
`.defaultValue`      | ❌      | ❌      | ❌   | ️✅     | ✅️
`.required`          | ❌      | ❌      | ❌   | ️✅     | ✅️
`.optional`          | ❌      | ❌      | ❌   | ️✅     | ✅️
`.repeating`         | ❌      | ❌      | ✅   | ️✅     | ✅️
`.topic`             | ❌      | ✅      | ❌   | ️❌     | ❌
`.topicGroup`        | ✅      | ✅      | ❌   | ️❌     | ❌
`.authors`           | ✅      | ❌      | ❌   | ️❌     | ❌
`.binaryName`        | ✅      | ❌      | ❌   | ️❌     | ❌


## Roadmap

See the [open issues](https://github.com/robik/commandr/issues) for a list of proposed features (and known issues).