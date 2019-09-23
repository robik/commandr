import std.stdio;
import commandr;

void main(string[] args) {
    Program p;

    try {
	    p = Program("test", "1.0")
            .summary("Command line parser")
            .author("John Doe <me@foo.bar.com>")
            .add(Flag("v", null, "turns on more verbose output")
                .name("verbose")
                .repeating)
            .add(Option(null, "test", "some teeeest"))
            .add(Command("help", "prints help"))
            .add(Command("dummy", "prints dummy text")
                .add(Flag("l", "loud", ""))
            )
            .add(Command("branch", "branch managament")
                .add(Command("add", "adds branch"))
                .add(Command("rm", "removes branch"))
            );

        auto a = p.parse(args);
        a.on("dummy", (args) {
            writefln("DUMMY command. verbose: %s, loud: %s on path %s", args.flag("verbose"), args.flag("loud"), a.arg("path"));
        }).on("branch", (args) {
            args.on("add", (args) {
                writeln("adding branch");
            }).on("rm", (args) {
                writeln("removing branch");
            });
        });
    } catch(InvalidProgramException e) {
        writeln("Whoops, program declaration is wrong: ", e.msg);
    } catch(InvalidArgumentsException e) {
        writeln("Error: ", e.msg);
        p.printUsage();
    }
}