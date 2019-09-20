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
            .add(Argument("path", "Path to file to edit")
                .required)
            ;

        auto a = p.parse(args);
        writeln("verbosity level", a.occurencesOf("verbose"));
        writeln("arg: ", a.arg("path"));
    } catch(InvalidProgramException e) {
        writeln("Whoops, program declaration is wrong: ", e.msg);
    } catch(InvalidArgumentsException e) {
        writeln("Error: ", e.msg);
        p.printUsage();
    }
}