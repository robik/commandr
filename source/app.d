import std.stdio;
import commandr;
import commandr.completion.bash;
import std.file;


void main(string[] args) {
    Program p;

    try {
	    p = new Program("commandr", "1.0")
            .summary("Command line parser")
            .author("John Doe <me@foo.bar.com>")
            .add(new Flag("v", null, "turns on more verbose output")
                .name("verbose")
                .repeating)
            .add(new Option("c", "config", "path to config file")
                .name("config")
                .acceptsFiles)
            .add(new Option("s", "scope", "scope type")
                .name("scope")
                .acceptsValues(["local", "global", "any"]))
            .add(new Option(null, "test", "some teeeest"))
            .add(new Command("help", "prints help"))
            .add(new Command("dummy", "prints dummy text")
                .add(new Flag("l", "loud", ""))
            )
            // .add(new Command("branch", "branch managament")
                // .add(new Command("add", "adds branch"))
                // .add(new Command("rm", "removes branch"))
            // )
            ;

        auto a = p.parse(args);
        a.on("dummy", (args) {
            writefln("DUMMY command. verbose: %s, loud: %s on path %s", args.flag("verbose"), args.flag("loud"), a.arg("path"));
            writefln("scope: %s, config: %s", args.option("scope"), args.option("config"));

            std.file.write("completion.bash", p.createBashCompletionScript());
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