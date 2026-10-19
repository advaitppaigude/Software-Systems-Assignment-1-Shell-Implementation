#include "s3.h"

int main(int argc, char *argv[]){

    ///Stores the command line input
    char line[MAX_LINE];

    ///Stores pointers to command arguments.
    ///The first element of the array is the command name.
    char *args[MAX_ARGS];

    ///Stores the number of arguments
    int argsc;

    int redir_status;
    Redirection redir;

    ///Shared REPL loop (Advait: redirection/pipes/execution | Srivathsan: lwd/cd/batches/subshells)
    while (1) {
        read_command_line(line);

        parse_command(line, args, &argsc);

        redir_status = parse_redirection(args, &argsc, &redir);

        if (redir_status == 0) {
            launch_program(args, argsc, &redir); 
            reap();
        }
    }

    return 0;
    
}
