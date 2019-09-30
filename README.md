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

 - [Example](#example)
 - [Installation](#installation)
 - [FAQ](#faq)
 - [Features](#features)
 - [Getting Started](#getting-started)
   - [Usage](#usage)
   - [Configuration](#configuration)
 - [Roadmap](#roadmap)
 - [License](#license)


## Example

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
   - Can be configured/partially overriden to suit your needs, such as forced disabling of ANSI codes.
   - Provided usage, help and version information.
   - Completly detached from core `Program`, giving you complete freedom in writing your own help output.

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
   - Suggestion with correct flag, option or sub-command name are provided when user specifies invalid value
   - Also supported for `EnumValidator` (`acceptsValues`)


## Getting Started

### Usage

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

### Configuration

## Roadmap

See the [open issues](https://github.com/robik/commandr/issues) for a list of proposed features (and known issues).